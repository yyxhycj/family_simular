local Data = require "Jiaye.Data"
local Art = require "Jiaye.Art"
---@diagnostic disable: undefined-global -- UrhoX runtime injects File/fileSystem/cjson.

local State = {}

State.SAVE_SCHEMA_VERSION = 2

local function UsesLegacyOpeningRules(draft)
    if type(draft) ~= "table" then return true end
    if type(draft.rulesVersion) == "number" then return draft.rulesVersion < 2 end
    return type(draft.generatorVersion) ~= "number" or draft.generatorVersion < 2
end

local KNOWN_RULES_VERSIONS = { [1] = true, [2] = true }

local function IsInteger(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
    return value == math.floor(value)
end

local function IsNonNegativeInteger(value)
    return IsInteger(value) and value >= 0
end

function State.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[State.Copy(key)] = State.Copy(item) end
    return copy
end

function State.NewProfile()
    return { schemaVersion = 1, unlockedRelicIds = { book = true, ruler = true, letter = true }, endingRecords = {} }
end

function State.BackgroundDefinition(draft)
    if type(draft) ~= "table" then return nil end
    if draft.backgroundId ~= nil then return Data.Background(draft.backgroundId) end
    for _, background in ipairs(Data.Backgrounds or {}) do
        if background.originId == draft.originId then return background end
    end
    return nil
end

-- 旧版兼容与验收基线；玩家新局由 Opening.Generate 生成。
function State.NewDraft()
    return {
        family = "林", worldId = "mortal", periodId = "peace", calendar = 72,
        originId = "artisan", placeId = "village", habitId = "none", tieId = "none",
        money = 80, grain = 24, land = 1, homeId = "simple", workshop = false, shop = false,
        selectedRelicIds = { "ruler" }, leaderId = 1, rngSeed = 72831, nextId = 5,
        members = {
            { id = 1, name = "林成", sex = "男", age = 42, artId = "portrait_m01", parents = {}, spouseId = 2, talent = 2, focus = "skill", experienceId = "craft", trait = "踏实", jobId = "craft" },
            { id = 2, name = "许青", sex = "女", age = 40, artId = "portrait_f01", parents = {}, spouseId = 1, talent = 2, focus = "general", experienceId = "basic", trait = "细致", jobId = "farm" },
            { id = 3, name = "林芸", sex = "女", age = 18, artId = "portrait_f02", parents = { 1, 2 }, spouseId = nil, talent = 3, focus = "medicine", experienceId = "none", trait = "仁厚", jobId = "medical" },
            { id = 4, name = "林安", sex = "男", age = 10, artId = "portrait_m02", parents = { 1, 2 }, spouseId = nil, talent = 3, focus = "learn", experienceId = "none", trait = "好奇", jobId = "study" },
        },
    }
end

function State.IsAdult(member)
    return type(member) == "table" and type(member.age) == "number" and member.age >= Data.AgeRules.adult
end

function State.BirthAgeRange(member)
    if type(member) ~= "table" then return nil end
    return Data.AgeRules.birth
end

function State.CanPlanBirth(member)
    if type(member) ~= "table" or member.alive == false then return false, "只有在世族人可以安排添丁计划。" end
    local range = State.BirthAgeRange(member)
    if member.age < range.min then return false, "添丁计划需满 " .. tostring(range.min) .. " 岁。" end
    if member.age > range.max then return false, "当前年龄已超过可安排窗口。" end
    return true, ""
end

function State.MemberBaseCost(member)
    local age = type(member) == "table" and member.age or nil
    if type(age) ~= "number" then return 0 end
    if age < Data.AgeRules.adult then return 4 end
    if age >= 55 then return 6 end
    return 8
end

function State.MemberCost(member)
    local talent = Data.Talents[member.talent] or Data.Talents[1]
    local experience = Data.Experience(member.experienceId)
    return State.MemberBaseCost(member) + talent.cost + (experience and experience.cost or 0)
end

function State.PointLines(draft)
    local rows, prices = {}, Data.OpeningCosts
    draft = type(draft) == "table" and draft or {}
    local function add(group, label, cost, effect)
        table.insert(rows, { group = group, label = label, cost = cost or 0, effect = effect or "" })
    end
    local period = Data.Period(draft.periodId)
    if period then
        add("world", period.name, period.cost,
            "工资倍率 " .. string.format("%.2f", period.wage) .. "；粮价 " .. tostring(period.food)
            .. " 两/石；生活开支倍率 " .. string.format("%.2f", period.expense))
    end
    for _, item in ipairs({ Data.Origin(draft.originId), Data.Place(draft.placeId) }) do
        if item then add("world", item.name, item.cost, item.desc) end
    end
    for _, member in ipairs(type(draft.members) == "table" and draft.members or {}) do
        member = type(member) == "table" and member or {}
        local talent, experience = Data.Talent(member.talent), Data.Experience(member.experienceId)
        local name = type(member.name) == "string" and member.name or "未命名成员"
        add("people", name .. " · 人口", State.MemberBaseCost(member), "姓名、性别不计点")
        add("people", name .. " · " .. talent.name, talent.cost, "成长修正 " .. tostring(talent.gain))
        if experience then add("people", name .. " · " .. experience.name, experience.cost, "已有本领") end
        local job = Data.Jobs[member.jobId]
        if job then add("people", name .. " · 初始安排：" .. job.name, 0, job.desc) end
    end
    local money = type(draft.money) == "number" and draft.money or 0
    local grain = type(draft.grain) == "number" and draft.grain or 0
    local land = type(draft.land) == "number" and draft.land or 0
    add("estate", "现银 " .. tostring(money) .. " 两", math.floor(money / prices.moneyUnit), "每 " .. prices.moneyUnit .. " 两 1 点")
    add("estate", "存粮 " .. tostring(grain) .. " 石", math.floor(grain / prices.grainUnit), "每 " .. prices.grainUnit .. " 石 1 点")
    add("estate", "田地 " .. tostring(land) .. " 亩", land * prices.land, "每亩每年收粮 4 石")
    local home = Data.Home(draft.homeId)
    if home then add("estate", home.name, home.cost, "每年维护 " .. home.upkeep .. " 两") end
    if draft.workshop then add("estate", "木工作坊", prices.workshop, "有手艺人经营，每年 +8 两") end
    if draft.shop then add("estate", "小商铺", prices.shop, "有经商族人经营，每年 +10 两") end
    if UsesLegacyOpeningRules(draft) then
        for _, item in ipairs({ Data.Habit(draft.habitId), Data.Tie(draft.tieId) }) do
            if item then add("estate", item.name, item.cost, item.desc) end
        end
    end
    local seen = {}
    for _, id in ipairs(type(draft.selectedRelicIds) == "table" and draft.selectedRelicIds or {}) do
        local relic = Data.Relic(id)
        if relic and not seen[id] then add("relics", relic.name, relic.cost, relic.desc); seen[id] = true end
    end
    return rows
end

function State.PointGroups(draft)
    local groups = { world = 0, people = 0, estate = 0, relics = 0 }
    for _, row in ipairs(State.PointLines(draft)) do groups[row.group] = groups[row.group] + row.cost end
    return groups
end

function State.TotalPoints(draft)
    local groups = State.PointGroups(draft)
    return groups.world + groups.people + groups.estate + groups.relics
end

function State.PageBudget(draft, page)
    local groups = State.PointGroups(draft)
    local used = groups[page] or 0
    return used, Data.LIMIT - (State.TotalPoints(draft) - used), Data.LIMIT - State.TotalPoints(draft)
end

function State.FindMember(members, id)
    for _, member in ipairs(type(members) == "table" and members or {}) do
        if type(member) == "table" and member.id == id then return member end
    end
    return nil
end

function State.Generation(members, memberId, visited)
    local member = State.FindMember(members, memberId)
    if not member then return 1 end
    visited = visited or {}
    if visited[memberId] then return 1 end
    visited[memberId] = true
    local generation = type(member.generation) == "number" and math.max(1, member.generation) or 1
    for _, parentId in ipairs(type(member.parents) == "table" and member.parents or {}) do
        generation = math.max(generation, State.Generation(members, parentId, visited) + 1)
    end
    visited[memberId] = nil
    return generation
end

local function HasCycle(members, member, targetId, visited)
    if member.id == targetId then return true end
    if visited[member.id] then return false end
    visited[member.id] = true
    for _, parentId in ipairs(type(member.parents) == "table" and member.parents or {}) do
        local parent = State.FindMember(members, parentId)
        if parent and HasCycle(members, parent, targetId, visited) then return true end
    end
    return false
end

function State.ValidName(name)
    if type(name) ~= "string" then return false end
    local length = utf8.len(name)
    if not length or length < 1 or length > 20 then return false end
    local visible = false
    for _, code in utf8.codes(name) do
        if code < 32 or code == 127 then return false end
        if code ~= 32 and code ~= 0x3000 and code ~= 0xA0 then visible = true end
    end
    return visible
end

local function List(value)
    return type(value) == "table" and value or {}
end

local function ValidOpeningAmount(value, unit)
    return type(value) == "number" and value >= 0 and value == math.floor(value) and value % unit == 0
end

function State.ValidateDraft(draft, profile, allowOverBudget)
    if type(draft) ~= "table" then return { "草案结构无效。" } end
    profile = type(profile) == "table" and profile or {}
    local unlockedRelicIds = type(profile.unlockedRelicIds) == "table" and profile.unlockedRelicIds or {}
    local issues, ids = {}, {}
    if draft.rulesVersion ~= nil and (not IsInteger(draft.rulesVersion) or not KNOWN_RULES_VERSIONS[draft.rulesVersion]) then table.insert(issues, "开局规则版本未知。") end
    if draft.worldId ~= "mortal" then table.insert(issues, "当前仅支持凡世开局。") end
    local period = Data.Period(draft.periodId)
    if not period then table.insert(issues, "请选择有效时期。")
    else
        local validYear = false
        for _, year in ipairs(period.years) do if year == draft.calendar then validYear = true end end
        if not validYear then table.insert(issues, "年份必须属于当前时期。") end
    end
    local origin = Data.Origin(draft.originId)
    if not origin or not Data.Place(draft.placeId) then table.insert(issues, "来历或地区无效。") end
    if draft.backgroundId ~= nil then
        local background = Data.Background(draft.backgroundId)
        if not background or (origin and background.originId ~= origin.id) then table.insert(issues, "背景定义与来历不匹配。") end
    end
    if not State.ValidName(draft.family) then table.insert(issues, "家族称谓须为 1–20 字，不能留空或包含换行。") end
    if not Data.Home(draft.homeId) or not Data.Habit(draft.habitId) or not Data.Tie(draft.tieId) then table.insert(issues, "住宅、家风或关系无效。") end
    local members = List(draft.members)
    if #members == 0 then table.insert(issues, "至少需要一位族人。") end
    for _, member in ipairs(members) do
        if type(member) ~= "table" then table.insert(issues, "成员数据无效。") member = {} end
        local name = type(member.name) == "string" and member.name or "成员"
        if not State.ValidName(member.name) then table.insert(issues, "成员姓名须为 1–20 字，不能留空或包含换行。") end
        if member.sex ~= "男" and member.sex ~= "女" then table.insert(issues, "成员性别无效。") end
        if not Data.FocusNames[member.focus] then table.insert(issues, "成员偏向无效。") end
        if type(member.id) ~= "number" or member.id < 1 or member.id ~= math.floor(member.id) then
            table.insert(issues, name .. "的成员编号无效。")
        elseif ids[member.id] then
            table.insert(issues, "成员编号重复：" .. tostring(member.id))
        else
            ids[member.id] = true
        end
        if type(member.age) ~= "number" or member.age < 0 or member.age > 92 or member.age ~= math.floor(member.age) then table.insert(issues, name .. "的年龄无效。") end
        local experience, job = Data.Experience(member.experienceId), Data.Jobs[member.jobId]
        if not Data.Talents[member.talent] or not experience or not job then
            table.insert(issues, name .. "的数据不完整。")
        elseif job.exam then
            table.insert(issues, name .. "须在本局通过应试后才能任职。")
        elseif member.age < job.min then
            table.insert(issues, name .. "的当前安排年龄不足。")
        elseif member.age < Data.AgeRules.adult and member.experienceId ~= "none" and member.experienceId ~= "basic" then
            table.insert(issues, "未成年族人只能选择“尚未专精”或“略通一二”。")
        elseif member.age < Data.AgeRules.basicExperience and member.experienceId ~= "none" then
            table.insert(issues, tostring(Data.AgeRules.basicExperience) .. " 岁前不能带入已有本领。")
        elseif job.req and (experience.values[job.req[1]] or 0) < job.req[2] then
            table.insert(issues, name .. "的当前安排尚未满足能力要求。")
        end
    end
    for _, member in ipairs(members) do
        if type(member) ~= "table" then member = {} end
        if member.spouseId then
            local spouse = State.FindMember(draft.members, member.spouseId)
            if not spouse or spouse.id == member.id or spouse.spouseId ~= member.id or type(member.age) ~= "number" or type(spouse.age) ~= "number" or not State.IsAdult(member) or not State.IsAdult(spouse) then table.insert(issues, tostring(member.name or "成员") .. "的婚配关系无效。") end
        end
        local parents = List(member.parents)
        if #parents > 2 then table.insert(issues, tostring(member.name or "成员") .. "最多两位父母/养亲。") end
        local seenParents = {}
        for _, parentId in ipairs(parents) do
            if seenParents[parentId] then table.insert(issues, "父母/养亲不能重复。") end
            seenParents[parentId] = true
            local parent = State.FindMember(members, parentId)
            if not parent or type(parent.age) ~= "number" or type(member.age) ~= "number" or parent.age - member.age < Data.AgeRules.parentDifference then table.insert(issues, tostring(member.name or "成员") .. "的亲缘关系无效。") end
            if parent and HasCycle(members, parent, member.id, {}) then table.insert(issues, "亲缘关系不能形成循环。") end
        end
    end
    local leader = State.FindMember(members, draft.leaderId)
    if not State.IsAdult(leader) then table.insert(issues, "需要指定一位成年首任族长。") end
    local relicSeen = {}
    if type(draft.selectedRelicIds) ~= "table" then table.insert(issues, "信物选择数据无效。") end
    for _, relicId in ipairs(List(draft.selectedRelicIds)) do
        if relicSeen[relicId] then table.insert(issues, "同一件信物不能重复带入。") end
        relicSeen[relicId] = true
        if not Data.Relic(relicId) then table.insert(issues, "信物不存在。") end
        if not unlockedRelicIds[relicId] then table.insert(issues, "尚未解锁信物：" .. tostring(relicId)) end
    end
    local prices = Data.OpeningCosts
    if not ValidOpeningAmount(draft.money, prices.moneyUnit)
        or not ValidOpeningAmount(draft.grain, prices.grainUnit)
        or not ValidOpeningAmount(draft.land, 1) then
        table.insert(issues, "家底须为非负整数；现银按 " .. tostring(prices.moneyUnit) .. " 两、存粮按 " .. tostring(prices.grainUnit) .. " 石调整。")
    end
    if type(draft.workshop) ~= "boolean" or type(draft.shop) ~= "boolean" then table.insert(issues, "产业选择数据无效。") end
    if not allowOverBudget and State.TotalPoints(draft) > Data.LIMIT then table.insert(issues, "总分超过 100，不能开始。") end
    return issues
end

function State.CanUseJob(member, jobId)
    local job = Data.Jobs[jobId]
    if not job then return false, "岗位不存在。" end
    if member.age < job.min then return false, "年龄不足，需要 " .. tostring(job.min) .. " 岁。" end
    if job.req and (member.stats[job.req[1]] or 0) < job.req[2] then return false, "需要 " .. job.req[1] .. " 达到 " .. tostring(job.req[2]) .. "。" end
    if job.exam and not member.examPassed then return false, "需先通过本局应试。" end
    return true, ""
end

---@return table?, string[]?
function State.NewRun(draft, profile)
    local issues = State.ValidateDraft(draft, profile, false)
    if #issues > 0 then return nil, issues end
    local period, origin = Data.Period(draft.periodId), Data.Origin(draft.originId)
    local newRules = not UsesLegacyOpeningRules(draft)
    local rulesVersion = newRules and Data.RULES_VERSION or (draft.rulesVersion or 1)
    if not KNOWN_RULES_VERSIONS[rulesVersion] then return nil, { "开局规则版本未知，不能开始。" } end
    local background = State.BackgroundDefinition(draft)
    if newRules and not background then return nil, { "当前开局缺少有效背景定义，不能开始。" } end
    local runId = "run-" .. tostring(os.time())
    local openingSnapshot = State.Copy(draft)
    openingSnapshot.rulesVersion = rulesVersion
    if background then
        openingSnapshot.backgroundId = background.id
        openingSnapshot.backgroundDefinition = State.Copy(background)
    end
    local members = {}
    for _, draftMember in ipairs(draft.members) do
        local member = State.Copy(draftMember)
        local experience = Data.Experience(member.experienceId)
        member.alive = true
        member.health = 60 + member.talent * 8
        member.stats = State.Copy(experience.values)
        member.jobYears = {}
        member.birthPlan = true
        member.lastBirthYear = -5
        member.hadHomeAfterGuard = false
        member.generation = State.Generation(draft.members, member.id)
        member.biography = { "大晟历 " .. tostring(draft.calendar) .. " 年，以“" .. Data.Jobs[member.jobId].name .. "”开始这一段人生。" }
        table.insert(members, member)
    end
    local relicInstances = {}
    for index, relicId in ipairs(draft.selectedRelicIds) do
        table.insert(relicInstances, {
            instanceId = "relic-" .. tostring(index), definitionId = relicId, status = "held", stage = "idle",
            source = "开局带入", custodianId = draft.leaderId, executorId = nil, rewardState = "none",
        })
    end
    local reputation = (origin.id == "gentry" and 25 or 0) + (draft.tieId == "neighbor" and 12 or 0)
    if draft.homeId == "estate" then reputation = reputation + 8 end
    local run = {
        runId = runId, schemaVersion = 1, rulesVersion = rulesVersion,
        openingSnapshot = openingSnapshot, backgroundId = background and background.id or nil, backgroundDefinition = background and State.Copy(background) or nil,
        worldId = draft.worldId, yearIndex = 0, calendar = draft.calendar, eraId = period.era, eraSinceYear = 0,
        placeId = draft.placeId, originId = draft.originId, habitId = draft.habitId, tieId = draft.tieId,
        members = members, leaderId = draft.leaderId, leaderTerms = { { memberId = draft.leaderId, startYear = 0, endYear = nil, effective = false, reason = "开局任命" } },
        money = draft.money, grain = draft.grain, land = draft.land, homeId = draft.homeId, workshop = draft.workshop, shop = draft.shop,
        reputation = reputation, relicInstances = relicInstances, events = {}, logs = {}, facts = {}, annualLedgers = {}, habitProgress = {}, habitFormations = {}, ending = nil, revision = 0,
        rngState = draft.rngSeed, processedCommands = {}, flags = {}, metrics = { stable = 0, foodYears = 0, aid = 0, migrations = 0, lastMove = 0 },
    }
    for _, member in ipairs(run.members) do
        State.AddFact(run, "opening", member.name .. "以“" .. Data.Jobs[member.jobId].name .. "”开始这一段人生。", { member.id }, { recordLog = false })
    end
    local leader = State.FindMember(run.members, run.leaderId)
    local firstTerm = run.leaderTerms[1]
    if leader and firstTerm then
        local fact = State.AddFact(run, "leadership", leader.name .. "受家人推举，成为首任族长。", { leader.id }, { reason = firstTerm.reason, leaderTermStart = 1, recordLog = false })
        firstTerm.factId = fact.id
    end
    return run, nil
end

function State.Random(run, min, max)
    run.rngState = (run.rngState * 48271) % 2147483647
    local value = run.rngState / 2147483647
    if min and max then return math.floor(min + value * (max - min + 1)) end
    return value
end

function State.AddLog(run, text, detail)
    run.logs = run.logs or {}
    run.nextHistoryId = run.nextHistoryId or (#run.logs + 1)
    local entry = { id = "history-" .. tostring(run.nextHistoryId), year = run.calendar, text = text }
    run.nextHistoryId = run.nextHistoryId + 1
    for key, value in pairs(type(detail) == "table" and detail or {}) do entry[key] = State.Copy(value) end
    table.insert(run.logs, 1, entry)
    return entry
end

function State.AddFact(run, kind, text, memberIds, detail)
    run.facts = run.facts or {}
    run.nextFactId = run.nextFactId or (#run.facts + 1)
    local fact = { id = "fact-" .. tostring(run.nextFactId), year = run.calendar, kind = kind, text = text, memberIds = State.Copy(memberIds or {}) }
    run.nextFactId = run.nextFactId + 1
    for key, value in pairs(type(detail) == "table" and detail or {}) do fact[key] = State.Copy(value) end
    table.insert(run.facts, 1, fact)
    if fact.recordLog ~= false then State.AddLog(run, text, { factId = fact.id, memberIds = fact.memberIds }) end
    for _, memberId in ipairs(fact.memberIds) do
        local member = State.FindMember(run.members, memberId)
        if member then
            member.factIds = member.factIds or {}
            table.insert(member.factIds, 1, fact.id)
        end
    end
    return fact
end

function State.RecordAnnualLedger(run, ledger, yearStart)
    run.annualLedgers = run.annualLedgers or {}
    run.nextLedgerId = run.nextLedgerId or (#run.annualLedgers + 1)
    local record = State.Copy(ledger)
    record.id = "ledger-" .. tostring(run.nextLedgerId)
    record.year = run.calendar
    record.yearIndex = run.yearIndex + 1
    record.yearStart = State.Copy(yearStart)
    run.nextLedgerId = run.nextLedgerId + 1
    table.insert(run.annualLedgers, 1, record)
    local fact = State.AddFact(run, "annual_ledger", "大晟历 " .. tostring(record.year) .. " 年账本已结算：银 " .. tostring(record.netMoney) .. " 两，粮 " .. tostring(record.netGrain) .. " 石。", {}, { ledgerId = record.id, recordLog = false })
    record.factId = fact.id
    return record
end

local KNOWN_SAVE_VERSIONS = { [1] = true, [2] = true }

---@return integer?, string?
local function ResolveCurrentSaveVersion(value)
    if type(value) ~= "table" then return nil, "存档顶层结构无效。" end
    local version = value.saveSchemaVersion
    if version == nil then
        if type(value.profile) == "table" and type(value.draft) == "table" then return 1 end
        return nil, "存档缺少可识别版本。"
    end
    if not IsInteger(version) or not KNOWN_SAVE_VERSIONS[version] then return nil, "存档版本未知，未执行迁移。" end
    return version
end

---@return boolean, string?
local function NormalizeMemberArt(members, identity, label)
    if type(members) ~= "table" then return false, label .. "成员列表结构无效。" end
    for index, member in ipairs(members) do
        if type(member) ~= "table" then return false, label .. "第 " .. tostring(index) .. " 位成员结构无效。" end
        local artId, message = Art.Assign(member, identity)
        if not artId then return false, label .. "第 " .. tostring(index) .. " 位成员的 artId 无法规范化：" .. tostring(message or "未知错误") end
    end
    return true
end

---@class JiayeSavePayload
---@field saveSchemaVersion integer
---@field profile table
---@field draft table
---@field run table?
---@field saveRevision integer?
---@field importReceipt string?

local function ImportReceipt(raw)
    local checksum = 0
    for index = 1, #raw do checksum = (checksum * 131 + string.byte(raw, index)) % 2147483647 end
    return "import-" .. tostring(#raw) .. "-" .. tostring(checksum)
end

local function MapLegacyMember(member, _family, runtime)
    if type(member) ~= "table" then return nil, "旧档成员结构无效。" end
    local mapped = State.Copy(member)
    mapped.id = member.id
    mapped.name = member.name
    mapped.nameSource = member.nameSource or "custom"
    mapped.sex = member.sex
    mapped.age = member.age
    mapped.artId = member.artId
    mapped.artVersion = member.artVersion
    mapped.ageAtDeath = member.ageAtDeath
    mapped.artStageAtDeath = member.artStageAtDeath
    mapped.parents = State.Copy(member.parents or {})
    mapped.spouseId = member.spouseId or member.spouse
    mapped.talent = member.talent
    mapped.focus = member.focus
    mapped.experienceId = member.experienceId or member.experience
    mapped.trait = member.trait
    mapped.jobId = member.jobId or member.job
    if runtime then
        local experience = Data.Experience(mapped.experienceId)
        local sourceStats = type(member.stats) == "table" and member.stats or member
        mapped.alive = member.alive ~= false
        mapped.health = member.health
        mapped.stats = {
            learn = sourceStats.learn or (experience and experience.values.learn), skill = sourceStats.skill or (experience and experience.values.skill),
            medicine = sourceStats.medicine or (experience and experience.values.medicine), trade = sourceStats.trade or (experience and experience.values.trade),
            martial = sourceStats.martial or (experience and experience.values.martial),
        }
        mapped.jobYears = State.Copy(member.jobYears or {})
        mapped.birthPlan = member.birthPlan ~= false
        mapped.lastBirthYear = member.lastBirthYear or member.lastBirth or -5
        mapped.hadHomeAfterGuard = member.hadHomeAfterGuard == true
        mapped.generation = member.generation or member.gen
        mapped.examPassed = member.examPassed == true
        mapped.deathYear = member.deathYear
        mapped.factIds = State.Copy(member.factIds or {})
        mapped.biography = {}
        for _, entry in ipairs(member.biography or member.bio or {}) do
            if type(entry) == "table" then table.insert(mapped.biography, tostring(entry.text or "旧版人生记录"))
            elseif type(entry) == "string" then table.insert(mapped.biography, entry) end
        end
        if #mapped.biography == 0 then table.insert(mapped.biography, "由 V5 存档迁入，原有安排与经历已保留。") end
    end
    return mapped
end

local function MapLegacyDraft(legacy, profile)
    if type(legacy) ~= "table" then return nil, "旧版草案缺失。" end
    local draft = State.Copy(legacy)
    draft.family = legacy.family
    draft.worldId = legacy.worldId or legacy.world
    draft.periodId = legacy.periodId or legacy.era
    draft.calendar = legacy.calendar
    draft.originId = legacy.originId or legacy.origin
    draft.placeId = legacy.placeId or legacy.place
    draft.habitId = legacy.habitId or legacy.habit
    draft.tieId = legacy.tieId or legacy.tie
    draft.money = legacy.money
    draft.grain = legacy.grain
    draft.land = legacy.land
    draft.homeId = legacy.homeId or legacy.home
    draft.workshop = legacy.workshop
    draft.shop = legacy.shop
    draft.selectedRelicIds = State.Copy(legacy.selectedRelicIds or legacy.relics or {})
    draft.leaderId = legacy.leaderId or legacy.leader
    draft.rngSeed = legacy.rngSeed or legacy.seed
    draft.nextId = legacy.nextId
    draft.members = {}
    for _, member in ipairs(legacy.members or {}) do
        local mapped, message = MapLegacyMember(member, draft.family, false)
        if not mapped then return nil, message end
        table.insert(draft.members, mapped)
    end
    local issues = State.ValidateDraft(draft, profile, true)
    if #issues > 0 then return nil, "旧版草案无法迁移：" .. tostring(issues[1]) end
    return draft
end

local function MapLegacyProfile(legacy)
    if type(legacy) ~= "table" or type(legacy.unlocked) ~= "table" or type(legacy.records) ~= "table" or type(legacy.endings) ~= "table" then
        return nil, "旧版收藏或终章记录结构无效。"
    end
    local profile = State.Copy(legacy)
    profile.schemaVersion = 1
    profile.unlockedRelicIds = {}
    profile.endingRecords = State.Copy(legacy.endings)
    profile.relicUnlockRecords = State.Copy(legacy.records)
    for _, relicId in ipairs(legacy.unlocked) do
        if not Data.Relic(relicId) then return nil, "旧版包含未知信物：" .. tostring(relicId) end
        profile.unlockedRelicIds[relicId] = true
    end
    return profile
end

local function MapLegacyRun(legacy, draft, profile)
    if type(legacy) ~= "table" or legacy.version ~= 3 or type(legacy.members) ~= "table" or type(legacy.logs) ~= "table" or type(legacy.events) ~= "table" or type(legacy.relics) ~= "table" then
        return nil, "旧版家谱结构或版本无效。"
    end
    local openingSnapshot, message = MapLegacyDraft(legacy.config or draft, profile)
    if not openingSnapshot then return nil, message end
    local run = State.Copy(legacy)
    run.runId = legacy.runId or "v5-run-" .. tostring(legacy.seed or 0)
    run.schemaVersion = 1
    run.rulesVersion = legacy.rulesVersion or 1
    run.openingSnapshot = openingSnapshot
    run.openingSnapshot.rulesVersion = run.rulesVersion
    run.worldId = openingSnapshot.worldId
    run.yearIndex = legacy.elapsed
    run.calendar = legacy.calendar
    run.eraId = legacy.era
    run.eraSinceYear = legacy.eraSince or 0
    run.placeId = legacy.place
    run.originId = openingSnapshot.originId
    run.habitId = openingSnapshot.habitId
    run.tieId = openingSnapshot.tieId
    run.members = {}
    run.leaderId = legacy.leader
    run.leaderTerms = {}
    run.money = legacy.money
    run.grain = legacy.grain
    run.land = legacy.land
    run.homeId = legacy.home
    run.workshop = legacy.workshop == true
    run.shop = legacy.shop == true
    run.reputation = legacy.reputation or 0
    run.relicInstances = {}
    run.events = {}
    run.logs = {}
    run.facts = {}
    run.annualLedgers = {}
    run.ending = nil
    run.revision = legacy.revision or 0
    run.rngState = ((legacy.rng or legacy.seed or 1) % 2147483646) + 1
    run.processedCommands = {}
    run.flags = State.Copy(legacy.flags or {})
    run.metrics = State.Copy(legacy.metrics or {})
    run.habitProgress = State.Copy(legacy.habitProgress or {})
    run.habitFormations = State.Copy(legacy.habitFormations or {})
    run.migratedFrom = "v5-schema-3"
    run.metrics.stable = run.metrics.stable or 0; run.metrics.foodYears = run.metrics.foodYears or 0
    run.metrics.aid = run.metrics.aid or 0; run.metrics.migrations = run.metrics.migrations or 0; run.metrics.lastMove = run.metrics.lastMove or 0
    for _, member in ipairs(legacy.members) do
        local mapped, issue = MapLegacyMember(member, openingSnapshot.family, true)
        if not mapped then return nil, issue end
        table.insert(run.members, mapped)
    end
    local relicByDefinition = {}
    for index, relic in ipairs(legacy.relics) do
        if type(relic) ~= "table" or not Data.Relic(relic.id) then return nil, "旧版物件引用无效。" end
        local stage = relic.phase == 1 and (relic.route == "slow" and "slow" or "fast") or (relic.phase == 2 and "completed" or "idle")
        local instance = {
            instanceId = "legacy-relic-" .. tostring(index), definitionId = relic.id, status = relic.status == "sold" and "sold" or (relic.phase == 1 and "investigating" or "held"),
            stage = stage, source = "V5 存档迁入", custodianId = relic.custodian, executorId = relic.actor,
            route = relic.route == "slow" and "slow" or (relic.route and "fast" or nil), dueYear = relic.due,
            rewardState = relic.phase == 2 and "granted" or "none", legacyHistory = State.Copy(relic.history or {}),
        }
        table.insert(run.relicInstances, instance)
        relicByDefinition[relic.id] = instance
    end
    for index = #legacy.logs, 1, -1 do
        local entry = legacy.logs[index]
        if type(entry) ~= "table" then return nil, "旧版年鉴条目无效。" end
        local text = tostring(entry.title or "旧版家史")
        if type(entry.body) == "string" and entry.body ~= "" then text = text .. "：" .. entry.body end
        table.insert(run.logs, 1, { id = "legacy-history-" .. tostring(index), year = openingSnapshot.calendar + (entry.year or 0), text = text, effects = State.Copy(entry.effects or {}), legacyEffects = State.Copy(entry.effects or {}) })
    end
    for index, term in ipairs(legacy.leaders or {}) do
        if type(term) ~= "table" then return nil, "旧版任期记录无效。" end
        table.insert(run.leaderTerms, { memberId = term.id, startYear = term.start or 0, endYear = term["end"], effective = (term["end"] or 0) > (term.start or 0), reason = term.reason or "V5 任期记录" })
    end
    if #run.leaderTerms == 0 then table.insert(run.leaderTerms, { memberId = run.leaderId, startYear = 0, endYear = nil, effective = false, reason = "V5 开局任命" }) end
    for index, event in ipairs(legacy.events) do
        if type(event) ~= "table" then return nil, "旧版待决事件无效。" end
        local relic = relicByDefinition[event.relic]
        local mapped = {
            instanceId = "legacy-event-" .. tostring(index), type = "legacy_pending", status = "pending", title = event.title or "旧版待决家事",
            legacyType = event.type, legacyDetail = State.Copy(event), blocking = false,
        }
        if event.type == "leader" then
            mapped.type = "leader"; mapped.title = "族长之位空缺"
        elseif event.type == "relicFinish" and relic then
            mapped.type = "relic_resolution"; mapped.relicInstanceId = relic.instanceId; mapped.executorId = relic.executorId
            mapped.title = Data.Relic(relic.definitionId).name .. "有了新的线索"; relic.status = "awaiting_resolution"; relic.stage = "awaiting_resolution"
        elseif relic and relic.status == "investigating" and relic.dueYear and relic.dueYear <= run.yearIndex then
            relic.status = "awaiting_resolution"; relic.stage = "awaiting_resolution"; mapped.type = "relic_resolution"; mapped.relicInstanceId = relic.instanceId; mapped.executorId = relic.executorId
            mapped.title = Data.Relic(relic.definitionId).name .. "有了新的线索"
        end
        table.insert(run.events, mapped)
    end
    if legacy.ended then
        local ending = Data.Ending(legacy.ended.id)
        if not ending then return nil, "旧版终章引用无效。" end
        run.ending = { id = ending.id, title = ending.title, type = ending.type, automatic = ending.automatic == true, year = run.calendar, yearIndex = run.yearIndex, leaderId = run.leaderId, summary = ending.desc, migratedFrom = "v5" }
        for _, event in ipairs(run.events) do if event.status == "pending" then event.status = "cancelled" end end
    end
    return run
end

local function ValidateProfile(profile)
    if type(profile) ~= "table" or profile.schemaVersion ~= 1 or type(profile.unlockedRelicIds) ~= "table" or type(profile.endingRecords) ~= "table" then return false, "收藏或终章记录结构无效。" end
    for relicId, unlocked in pairs(profile.unlockedRelicIds) do if unlocked and not Data.Relic(relicId) then return false, "收藏包含未知信物。" end end
    for _, record in ipairs(profile.endingRecords) do if type(record) ~= "table" or not Data.Ending(record.id) then return false, "终章记录包含未知引用。" end end
    return true
end

local function ValidateRun(run)
    if type(run) ~= "table" or run.schemaVersion ~= 1 or not IsNonNegativeInteger(run.yearIndex) or not IsInteger(run.calendar)
        or not Data.Period(run.eraId) or not Data.Place(run.placeId) or not Data.Origin(run.originId) or not Data.Habit(run.habitId) or not Data.Tie(run.tieId)
        or not Data.Home(run.homeId) or type(run.members) ~= "table" or type(run.logs) ~= "table" or type(run.events) ~= "table"
        or type(run.leaderTerms) ~= "table" or type(run.relicInstances) ~= "table" or type(run.facts) ~= "table" or type(run.annualLedgers) ~= "table"
        or type(run.habitProgress) ~= "table" or type(run.habitFormations) ~= "table"
        or not IsInteger(run.rulesVersion) or not KNOWN_RULES_VERSIONS[run.rulesVersion]
        or not IsInteger(run.rngState) or run.rngState < 1 or run.rngState >= 2147483647 then
        return false, "家谱结构、版本或基础引用无效。"
    end
    if run.rulesVersion >= 2 and (not Data.Background(run.backgroundId) or type(run.backgroundDefinition) ~= "table") then return false, "新规则家谱缺少背景定义。" end
    local memberIds, relicIds = {}, {}
    for _, member in ipairs(run.members) do
        if type(member) ~= "table" or not IsNonNegativeInteger(member.id) or member.id < 1 or memberIds[member.id]
            or not State.ValidName(member.name) or (member.sex ~= "男" and member.sex ~= "女") or not IsNonNegativeInteger(member.age)
            or not Data.Talents[member.talent] or not Data.FocusNames[member.focus] or not Data.Experience(member.experienceId) or not Data.Jobs[member.jobId]
            or type(member.stats) ~= "table" or type(member.jobYears) ~= "table" or type(member.biography) ~= "table" then
            return false, "家谱成员结构或引用无效。"
        end
        memberIds[member.id] = true
    end
    if not memberIds[run.leaderId] then return false, "族长引用无效。" end
    for _, member in ipairs(run.members) do
        for _, parentId in ipairs(member.parents or {}) do if not memberIds[parentId] then return false, "亲缘引用无效。" end end
        if member.spouseId and not memberIds[member.spouseId] then return false, "婚配引用无效。" end
    end
    for _, relic in ipairs(run.relicInstances) do
        if type(relic) ~= "table" or type(relic.instanceId) ~= "string" or relicIds[relic.instanceId] or not Data.Relic(relic.definitionId)
            or (relic.custodianId and not memberIds[relic.custodianId]) or (relic.executorId and not memberIds[relic.executorId]) then
            return false, "本局物件结构或引用无效。"
        end
        relicIds[relic.instanceId] = true
    end
    for _, term in ipairs(run.leaderTerms) do if type(term) ~= "table" or not memberIds[term.memberId] then return false, "任期引用无效。" end end
    for _, event in ipairs(run.events) do
        if type(event) ~= "table" or type(event.instanceId) ~= "string" or (event.memberId and not memberIds[event.memberId])
            or (event.executorId and not memberIds[event.executorId]) or (event.relicInstanceId and not relicIds[event.relicInstanceId]) then
            return false, "待决事件引用无效。"
        end
    end
    for _, fact in ipairs(run.facts) do
        if type(fact) ~= "table" or type(fact.memberIds) ~= "table" then return false, "事实记录结构无效。" end
        for _, memberId in ipairs(fact.memberIds) do if not memberIds[memberId] then return false, "事实记录参与人无效。" end end
    end
    if run.ending and (type(run.ending) ~= "table" or not Data.Ending(run.ending.id)) then return false, "终章引用无效。" end
    return true
end

---@return boolean, string?
local function ValidateSavePayloadInternal(value)
    local version, versionMessage = ResolveCurrentSaveVersion(value)
    if not version then return false, versionMessage end
    local profile, draft, run = value.profile, value.draft, value.run
    local profileOk, profileMessage = ValidateProfile(profile)
    if not profileOk then return false, profileMessage end
    local issues = State.ValidateDraft(draft, profile, true)
    if #issues > 0 then return false, "开局草案结构或引用无效：" .. tostring(issues[1]) end
    if run then
        local runOk, runMessage = ValidateRun(run)
        if not runOk then return false, runMessage end
    end
    return true
end

---@return boolean, string?
function State.ValidateSavePayload(value)
    local protected, valid, message = pcall(ValidateSavePayloadInternal, value)
    if not protected or type(valid) ~= "boolean" then return false, "存档结构校验异常，当前内容未采用。" end
    return valid, type(message) == "string" and message or nil
end

---@return JiayeSavePayload?, string?
local function NormalizeCurrentPayload(value, sourceVersion)
    if not KNOWN_SAVE_VERSIONS[sourceVersion] then return nil, "存档版本未知，未执行迁移。" end
    ---@type JiayeSavePayload
    local candidate = State.Copy(value)
    if type(candidate) ~= "table" then return nil, "存档顶层结构无效。" end
    candidate.profile = candidate.profile or State.NewProfile()
    candidate.profile.schemaVersion = candidate.profile.schemaVersion or 1
    candidate.profile.unlockedRelicIds = candidate.profile.unlockedRelicIds or { book = true, ruler = true, letter = true }
    candidate.profile.endingRecords = candidate.profile.endingRecords or {}
    local identity = candidate.run and candidate.run.runId or (candidate.draft and candidate.draft.rngSeed) or "draft"
    if candidate.draft then
        if type(candidate.draft) ~= "table" then return nil, "开局草案结构无效。" end
        local draftArtOk, draftArtMessage = NormalizeMemberArt(candidate.draft.members, identity, "开局草案")
        if not draftArtOk then return nil, draftArtMessage end
    end
    if candidate.run then
        local run = candidate.run
        if type(run) ~= "table" then return nil, "运行家谱结构无效。" end
        run.schemaVersion = run.schemaVersion or 1
        run.openingSnapshot = run.openingSnapshot or State.Copy(candidate.draft)
        if type(run.openingSnapshot) ~= "table" then return nil, "开局快照结构无效。" end
        local rulesVersion = run.rulesVersion
        local snapshotVersion = run.openingSnapshot.rulesVersion
        if snapshotVersion ~= nil and (not IsInteger(snapshotVersion) or not KNOWN_RULES_VERSIONS[snapshotVersion]) then
            return nil, "开局快照规则版本未知，未迁移。"
        end
        if rulesVersion == nil then
            local generatorVersion = run.openingSnapshot.generatorVersion
            if snapshotVersion == nil and generatorVersion ~= nil and generatorVersion ~= 1 and generatorVersion ~= 2 then
                return nil, "开局生成版本未知，无法确认运行规则。"
            end
            rulesVersion = snapshotVersion or (generatorVersion == 2 and 2 or 1)
        end
        if not IsInteger(rulesVersion) or not KNOWN_RULES_VERSIONS[rulesVersion] then return nil, "运行规则版本未知，未迁移。" end
        if snapshotVersion and snapshotVersion ~= rulesVersion then return nil, "开局快照与运行规则版本不一致。" end
        run.rulesVersion = rulesVersion
        run.openingSnapshot.rulesVersion = rulesVersion
        if rulesVersion >= 2 then
            local background = State.BackgroundDefinition(run.openingSnapshot)
            if not background then return nil, "新规则家谱缺少有效背景定义。" end
            if run.backgroundId ~= nil and run.backgroundId ~= background.id then return nil, "运行家谱背景定义与开局快照不一致。" end
            run.openingSnapshot.backgroundId = background.id
            run.openingSnapshot.backgroundDefinition = run.openingSnapshot.backgroundDefinition or State.Copy(background)
            if type(run.openingSnapshot.backgroundDefinition) ~= "table" or run.openingSnapshot.backgroundDefinition.id ~= background.id then return nil, "开局快照背景定义结构无效。" end
            run.backgroundId = background.id
            if run.backgroundDefinition == nil then run.backgroundDefinition = State.Copy(background) end
            if type(run.backgroundDefinition) ~= "table" or run.backgroundDefinition.id ~= background.id then return nil, "运行家谱背景定义结构无效。" end
        end
        run.facts = run.facts or {}
        run.annualLedgers = run.annualLedgers or {}
        run.habitProgress = run.habitProgress or {}
        run.habitFormations = run.habitFormations or {}
        if type(run.habitProgress) ~= "table" or type(run.habitFormations) ~= "table" then return nil, "家风进度结构无效。" end
        run.processedCommands = run.processedCommands or {}
        run.revision = run.revision or 0
        run.metrics = run.metrics or {}
        run.metrics.stable = run.metrics.stable or 0
        run.metrics.foodYears = run.metrics.foodYears or 0
        run.metrics.aid = run.metrics.aid or 0
        run.metrics.migrations = run.metrics.migrations or 0
        run.metrics.lastMove = run.metrics.lastMove or 0
        local runIdentity = run.runId or identity
        local snapshotArtOk, snapshotArtMessage = NormalizeMemberArt(run.openingSnapshot.members, runIdentity, "开局快照")
        if not snapshotArtOk then return nil, snapshotArtMessage end
        local runArtOk, runArtMessage = NormalizeMemberArt(run.members, runIdentity, "运行家谱")
        if not runArtOk then return nil, runArtMessage end
        for _, member in ipairs(run.members) do
            member.factIds = member.factIds or {}
            member.biography = member.biography or {}
            member.stats = member.stats or State.Copy((Data.Experience(member.experienceId) or Data.Experience("none")).values)
            member.jobYears = member.jobYears or {}
        end
    end
    candidate.saveSchemaVersion = State.SAVE_SCHEMA_VERSION
    if sourceVersion == 1 then candidate.migratedFromSaveSchemaVersion = 1 end
    return candidate
end

-- 两个交替存档位：只写非最新的一份，失败时保留上次可读进度。
---@type string[]
local SAVE_PATHS = { "jiaye_save.json", "jiaye_save.backup.json" }
---@type string?
local failedSavePath = nil

---@return string?
local function ReadFile(path)
    local file = File(path, FILE_READ)
    if not file:IsOpen() then return nil end
    local protected, raw = pcall(function() return file:ReadString() end)
    file:Close()
    if not protected or type(raw) ~= "string" then return nil end
    return raw
end

---@return JiayeSavePayload?, string?, string?
local function ReadSlot(path)
    -- 本进程未确认成功的候选不参与选档；首次保存失败后仍能原地重试。
    -- 重启后没有此标记，仍按磁盘内容检查，绝不自行覆盖未知坏档。
    if path == failedSavePath then return nil, "unconfirmed" end
    if not fileSystem:FileExists(path) then return nil, "missing" end
    local raw = ReadFile(path)
    if not raw then return nil, "unreadable" end
    local ok, value = pcall(cjson.decode, raw)
    if not ok or type(value) ~= "table" then return nil, "invalid" end
    local versionProtected, sourceVersion, versionMessage = pcall(ResolveCurrentSaveVersion, value)
    if not versionProtected or not sourceVersion then return nil, "invalid", versionProtected and versionMessage or "存档版本校验异常。" end
    local normalizedProtected, normalized, normalizeMessage = pcall(NormalizeCurrentPayload, value, sourceVersion)
    if not normalizedProtected or type(normalized) ~= "table" then return nil, "invalid", normalizedProtected and normalizeMessage or "存档归一化异常。" end
    ---@type JiayeSavePayload
    local save = normalized
    local valid, validationMessage = State.ValidateSavePayload(save)
    if not valid then return nil, "invalid", validationMessage end
    local revision = save.saveRevision or 0 -- 兼容现有未编号存档。
    if type(revision) ~= "number" or revision < 0 or revision ~= math.floor(revision) or revision == math.huge then return nil, "invalid" end
    save.saveRevision = revision
    return save, "ok"
end

---@return JiayeSavePayload?, integer?, boolean, boolean
local function LatestSave()
    local latest, index, problem, unreadable = nil, nil, false, false
    for slot, path in ipairs(SAVE_PATHS) do
        local protected, value, status = pcall(ReadSlot, path)
        if protected then
            if type(value) == "table" and (not latest or value.saveRevision > latest.saveRevision) then latest, index = value, slot end
            if status == "invalid" or status == "unreadable" then problem = true end
            if status == "unreadable" then unreadable = true end
        else
            -- 单个槽的文件、解析或校验异常不得打断另一个槽的读取。
            problem = true
            unreadable = true
        end
    end
    return latest, index, problem, unreadable
end

---@return boolean
local function WriteVerified(path, raw)
    local file = File(path, FILE_WRITE)
    if not file:IsOpen() then return false end
    local ok, written = pcall(function() return file:WriteString(raw) end)
    file:Close()
    -- UrhoX WriteString 返回 boolean，不能把 0 或任意 truthy 值当成功。
    return ok and written == true and ReadFile(path) == raw
end

---@return boolean, string
function State.Save(profile, draft, run, metadata)
    local previous, index, problem, unreadable = LatestSave()
    local allowRecoveryOverwrite = type(metadata) == "table" and metadata.allowRecoveryOverwrite == true
    if (unreadable or (problem and not previous)) and not allowRecoveryOverwrite then return false, "旧存档无法安全读取，已停止覆盖；请保留原文件并导出当前进度。" end
    ---@type JiayeSavePayload
    local payload = {
        saveSchemaVersion = State.SAVE_SCHEMA_VERSION, profile = State.Copy(profile), draft = State.Copy(draft), run = State.Copy(run),
        saveRevision = (previous and previous.saveRevision or 0) + 1,
    }
    if type(metadata) == "table" and type(metadata.importReceipt) == "string" then payload.importReceipt = metadata.importReceipt end
    local normalizedProtected, normalized, normalizeMessage = pcall(NormalizeCurrentPayload, payload, State.SAVE_SCHEMA_VERSION)
    if not normalizedProtected or type(normalized) ~= "table" then return false, normalizedProtected and (normalizeMessage or "当前进度归一化失败。") or "当前进度归一化异常，未写入。" end
    ---@type JiayeSavePayload
    local normalizedPayload = normalized
    payload = normalizedPayload
    local valid, validationMessage = State.ValidateSavePayload(payload)
    if not valid then return false, "当前进度无法保存：" .. tostring(validationMessage or "结构校验失败。") end
    local encoded, raw = pcall(cjson.encode, payload)
    if not encoded or type(raw) ~= "string" then return false, "存档编码失败，当前进度仍在内存中。" end
    local targetPath = index == 1 and SAVE_PATHS[2] or SAVE_PATHS[1]
    local written, verified = pcall(WriteVerified, targetPath, raw)
    if not written or not verified then
        failedSavePath = targetPath
        return false, "存档写入或回读失败，当前进度仍在内存中，已有可读存档未覆盖；请重试保存或导出。"
    end
    failedSavePath = nil
    return true, "进度已保存并回读核对，上次可读存档仍保留。"
end

---@return JiayeSavePayload?, string, string
function State.Load()
    local value, _, problem = LatestSave()
    if value then
        return value, problem and "一份存档不可读，已恢复另一份可读进度；请核对年份。" or "已读取最近存档。", problem and "recovered" or "ok"
    end
    return nil, problem and "本地存档不可读，已停止开新局以保护旧进度；请保留原文件。" or "尚无本地存档。", problem and "invalid" or "missing"
end

---@return JiayeSavePayload?, string, string
function State.PreflightImport(raw)
    if type(raw) ~= "string" or raw == "" then return nil, "请粘贴完整的备份 JSON。", "invalid" end
    if #raw > 15000000 then return nil, "备份文件超过 15MB，已停止解析。", "invalid" end
    local ok, value = pcall(cjson.decode, raw)
    if not ok or type(value) ~= "table" then return nil, "备份 JSON 无法解析，当前进度未改动。", "invalid" end
    ---@type JiayeSavePayload?
    local candidate = nil
    ---@type string?
    local source = nil
    if value.schema == 3 then
        if value.saveSchemaVersion ~= nil then return nil, "备份同时包含未知的顶层版本标记，当前进度未改动。", "invalid" end
        local profile, profileMessage = MapLegacyProfile(value.profile)
        if not profile then return nil, profileMessage, "invalid" end
        local draft, draftMessage = MapLegacyDraft(value.draft, profile)
        if not draft then return nil, draftMessage, "invalid" end
        local run, runMessage = nil, nil
        if value.game ~= nil then run, runMessage = MapLegacyRun(value.game, draft, profile) end
        if runMessage then return nil, runMessage, "invalid" end
        candidate = { saveSchemaVersion = State.SAVE_SCHEMA_VERSION, profile = profile, draft = draft, run = run, migratedFrom = "v5-schema-3" }
        source = "V5 存档"
    else
        local versionProtected, sourceVersion, versionMessage = pcall(ResolveCurrentSaveVersion, value)
        if not versionProtected or not sourceVersion then return nil, versionProtected and versionMessage or "备份版本校验异常，当前进度未改动。", "invalid" end
        local normalizedProtected, normalized, normalizeMessage = pcall(NormalizeCurrentPayload, value, sourceVersion)
        if not normalizedProtected or type(normalized) ~= "table" then return nil, normalizedProtected and normalizeMessage or "备份归一化异常，当前进度未改动。", "invalid" end
        candidate = normalized
        source = "当前格式"
    end
    if type(candidate) ~= "table" or type(source) ~= "string" then return nil, "备份结构未形成可确认候选，当前进度未改动。", "invalid" end
    local normalizedProtected, normalized, normalizeMessage = pcall(NormalizeCurrentPayload, candidate, State.SAVE_SCHEMA_VERSION)
    if not normalizedProtected or type(normalized) ~= "table" then return nil, normalizedProtected and (normalizeMessage or "备份归一化失败，当前进度未改动。") or "备份归一化异常，当前进度未改动。", "invalid" end
    ---@type JiayeSavePayload
    local normalizedCandidate = normalized
    candidate = normalizedCandidate
    candidate.saveRevision = nil
    candidate.importReceipt = ImportReceipt(raw)
    local valid, message = State.ValidateSavePayload(candidate)
    if not valid then return nil, "备份校验失败：" .. tostring(message or "结构校验失败。"), "invalid" end
    local pending = candidate.run and #candidate.run.events or 0
    local years = candidate.run and candidate.run.yearIndex or 0
    return candidate, source .. "已通过结构、版本与引用校验：经营 " .. tostring(years) .. " 年，待决家事 " .. tostring(pending) .. " 件。确认后才会替换当前进度。", "ready"
end

function State.Import(raw)
    return State.PreflightImport(raw)
end

function State.ReadExport()
    local raw = ReadFile("jiaye_export.json")
    if not raw then return nil, "本机尚无可读取的家谱备份。" end
    return State.PreflightImport(raw)
end

---@param candidate JiayeSavePayload
function State.CommitImport(candidate)
    if type(candidate) ~= "table" then return false, "没有可确认的导入内容。", "invalid" end
    local valid, validationMessage = State.ValidateSavePayload(candidate)
    if not valid then return false, "导入内容已失效：" .. tostring(validationMessage or "结构校验失败。"), "invalid" end
    local latest = LatestSave()
    if latest and latest.importReceipt and latest.importReceipt == candidate.importReceipt then
        return true, "这份备份已经导入，当前进度保持不变。", "duplicate"
    end
    local ok, message = State.Save(candidate.profile, candidate.draft, candidate.run, { importReceipt = candidate.importReceipt, allowRecoveryOverwrite = true })
    if not ok then return false, message, "failed" end
    return true, "备份已原子写入并回读核对。", "committed"
end

---@return string?, string
function State.Export(profile, draft, run)
    ---@type JiayeSavePayload
    local payload = { saveSchemaVersion = State.SAVE_SCHEMA_VERSION, profile = State.Copy(profile), draft = State.Copy(draft), run = State.Copy(run) }
    local normalizedProtected, normalized, normalizeMessage = pcall(NormalizeCurrentPayload, payload, State.SAVE_SCHEMA_VERSION)
    if not normalizedProtected or type(normalized) ~= "table" then return nil, normalizedProtected and (normalizeMessage or "当前进度归一化失败，未导出。") or "当前进度归一化异常，未导出。" end
    ---@type JiayeSavePayload
    local normalizedPayload = normalized
    payload = normalizedPayload
    local valid, validationMessage = State.ValidateSavePayload(payload)
    if not valid then return nil, "当前进度无法导出：" .. tostring(validationMessage or "结构校验失败。") end
    local encoded, raw = pcall(cjson.encode, payload)
    if not encoded or type(raw) ~= "string" then return nil, "备份编码失败，未导出。" end
    if not WriteVerified("jiaye_export.json", raw) then return nil, "备份写入或回读失败，未确认导出成功。" end
    return raw, "备份已写入 jiaye_export.json 并回读核对。"
end

return State
