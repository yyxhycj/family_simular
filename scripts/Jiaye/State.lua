local Data = require "Jiaye.Data"

local State = {}

function State.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[State.Copy(key)] = State.Copy(item) end
    return copy
end

function State.NewProfile()
    return { schemaVersion = 1, unlockedRelicIds = { book = true, ruler = true, letter = true }, endingRecords = {} }
end

function State.NewDraft()
    return {
        family = "林", worldId = "mortal", periodId = "peace", calendar = 72,
        originId = "artisan", placeId = "village", habitId = "none", tieId = "none",
        money = 80, grain = 24, land = 1, homeId = "simple", workshop = false, shop = false,
        selectedRelicIds = { "ruler" }, leaderId = 1, rngSeed = 72831, nextId = 5,
        members = {
            { id = 1, name = "林成", sex = "男", age = 42, parents = {}, spouseId = 2, talent = 2, focus = "skill", experienceId = "craft", trait = "踏实", jobId = "craft" },
            { id = 2, name = "许青", sex = "女", age = 40, parents = {}, spouseId = 1, talent = 2, focus = "general", experienceId = "basic", trait = "细致", jobId = "farm" },
            { id = 3, name = "林芸", sex = "女", age = 18, parents = { 1, 2 }, spouseId = nil, talent = 3, focus = "medicine", experienceId = "none", trait = "仁厚", jobId = "medical" },
            { id = 4, name = "林安", sex = "男", age = 10, parents = { 1, 2 }, spouseId = nil, talent = 3, focus = "learn", experienceId = "none", trait = "好奇", jobId = "study" },
        },
    }
end

function State.MemberBaseCost(member)
    if member.age < 18 then return 4 end
    if member.age >= 55 then return 6 end
    return 8
end

function State.MemberCost(member)
    local talent = Data.Talents[member.talent] or Data.Talents[1]
    local experience = Data.Experience(member.experienceId)
    return State.MemberBaseCost(member) + talent.cost + (experience and experience.cost or 0)
end

function State.PointGroups(draft)
    local world = (Data.Period(draft.periodId) and Data.Period(draft.periodId).cost or 0)
        + (Data.Origin(draft.originId) and Data.Origin(draft.originId).cost or 0)
        + (Data.Place(draft.placeId) and Data.Place(draft.placeId).cost or 0)
    local people = 0
    for _, member in ipairs(draft.members) do people = people + State.MemberCost(member) end
    local estate = math.floor(draft.money / 10) + math.floor(draft.grain / 4) + draft.land * 4
        + (Data.Home(draft.homeId) and Data.Home(draft.homeId).cost or 0)
        + (draft.workshop and 14 or 0) + (draft.shop and 20 or 0)
        + (Data.Habit(draft.habitId) and Data.Habit(draft.habitId).cost or 0)
        + (Data.Tie(draft.tieId) and Data.Tie(draft.tieId).cost or 0)
    local relics, seen = 0, {}
    for _, relicId in ipairs(draft.selectedRelicIds) do
        if not seen[relicId] then
            seen[relicId] = true
            local relic = Data.Relic(relicId)
            relics = relics + (relic and relic.cost or 0)
        end
    end
    return { world = world, people = people, estate = estate, relics = relics }
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
    for _, member in ipairs(members) do if member.id == id then return member end end
    return nil
end

function State.Generation(members, memberId, visited)
    local member = State.FindMember(members, memberId)
    if not member then return 1 end
    visited = visited or {}
    if visited[memberId] then return 1 end
    visited[memberId] = true
    local generation = 1
    for _, parentId in ipairs(member.parents or {}) do
        generation = math.max(generation, State.Generation(members, parentId, visited) + 1)
    end
    visited[memberId] = nil
    return generation
end

local function HasCycle(members, member, targetId, visited)
    if member.id == targetId then return true end
    if visited[member.id] then return false end
    visited[member.id] = true
    for _, parentId in ipairs(member.parents or {}) do
        local parent = State.FindMember(members, parentId)
        if parent and HasCycle(members, parent, targetId, visited) then return true end
    end
    return false
end

function State.ValidateDraft(draft, profile, allowOverBudget)
    local issues, ids = {}, {}
    local period = Data.Period(draft.periodId)
    if not period then table.insert(issues, "请选择有效时期。")
    else
        local validYear = false
        for _, year in ipairs(period.years) do if year == draft.calendar then validYear = true end end
        if not validYear then table.insert(issues, "年份必须属于当前时期。") end
    end
    if not Data.Origin(draft.originId) or not Data.Place(draft.placeId) then table.insert(issues, "来历或地区无效。") end
    if #draft.members == 0 then table.insert(issues, "至少需要一位族人。") end
    for _, member in ipairs(draft.members) do
        if ids[member.id] then table.insert(issues, "成员编号重复：" .. tostring(member.id)) end
        ids[member.id] = true
        if type(member.age) ~= "number" or member.age < 0 or member.age > 92 or member.age ~= math.floor(member.age) then table.insert(issues, member.name .. "的年龄无效。") end
        local experience, job = Data.Experience(member.experienceId), Data.Jobs[member.jobId]
        if not Data.Talents[member.talent] or not experience or not job then
            table.insert(issues, member.name .. "的数据不完整。")
        elseif member.age < job.min then
            table.insert(issues, member.name .. "的当前安排年龄不足。")
        elseif member.age < 18 and member.experienceId ~= "none" and member.experienceId ~= "basic" then
            table.insert(issues, "未成年族人只能选择“尚未专精”或“略通一二”。")
        elseif member.age < 8 and member.experienceId ~= "none" then
            table.insert(issues, "8 岁前不能带入已有本领。")
        elseif job.req and (experience.values[job.req[1]] or 0) < job.req[2] then
            table.insert(issues, member.name .. "的当前安排尚未满足能力要求。")
        end
    end
    for _, member in ipairs(draft.members) do
        if member.spouseId then
            local spouse = State.FindMember(draft.members, member.spouseId)
            if not spouse or spouse.spouseId ~= member.id or member.age < 18 or spouse.age < 18 then table.insert(issues, member.name .. "的婚配关系无效。") end
        end
        for _, parentId in ipairs(member.parents or {}) do
            local parent = State.FindMember(draft.members, parentId)
            if not parent or parent.age - member.age < 18 then table.insert(issues, member.name .. "的亲缘关系无效。") end
            if parent and HasCycle(draft.members, parent, member.id, {}) then table.insert(issues, "亲缘关系不能形成循环。") end
        end
    end
    local leader = State.FindMember(draft.members, draft.leaderId)
    if not leader or leader.age < 18 then table.insert(issues, "需要指定一位成年首任族长。") end
    local relicSeen = {}
    for _, relicId in ipairs(draft.selectedRelicIds) do
        if relicSeen[relicId] then table.insert(issues, "同一件信物不能重复带入。") end
        relicSeen[relicId] = true
        if not profile.unlockedRelicIds[relicId] then table.insert(issues, "尚未解锁信物：" .. tostring(relicId)) end
    end
    if draft.money < 0 or draft.grain < 0 or draft.land < 0 then table.insert(issues, "家底不能为负。") end
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

function State.NewRun(draft, profile)
    local issues = State.ValidateDraft(draft, profile, false)
    if #issues > 0 then return nil, issues end
    local period, origin = Data.Period(draft.periodId), Data.Origin(draft.originId)
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
    for index, relicId in ipairs(draft.selectedRelicIds) do table.insert(relicInstances, { instanceId = "relic-" .. tostring(index), definitionId = relicId, status = "held", custodianId = draft.leaderId, stage = "idle" }) end
    local reputation = origin.id == "gentry" and 25 or (draft.tieId == "neighbor" and 12 or 0)
    if draft.homeId == "estate" then reputation = reputation + 8 end
    return {
        runId = "run-" .. tostring(os.time()), schemaVersion = 1, rulesVersion = Data.RULES_VERSION,
        openingSnapshot = State.Copy(draft), yearIndex = 0, calendar = draft.calendar, eraId = period.era, eraSinceYear = 0,
        placeId = draft.placeId, originId = draft.originId, habitId = draft.habitId, tieId = draft.tieId,
        members = members, leaderId = draft.leaderId, leaderTerms = { { memberId = draft.leaderId, startYear = 0, endYear = nil, effective = false, reason = "开局任命" } },
        money = draft.money, grain = draft.grain, land = draft.land, homeId = draft.homeId, workshop = draft.workshop, shop = draft.shop,
        reputation = reputation, relicInstances = relicInstances, events = {}, logs = {}, ending = nil, revision = 0,
        rngState = draft.rngSeed, processedCommands = {}, flags = {}, metrics = { stable = 0, foodYears = 0, aid = 0, migrations = 0, lastMove = 0 },
    }, nil
end

function State.Random(run, min, max)
    run.rngState = (run.rngState * 48271) % 2147483647
    local value = run.rngState / 2147483647
    if min and max then return math.floor(min + value * (max - min + 1)) end
    return value
end

function State.AddLog(run, text)
    table.insert(run.logs, 1, { year = run.calendar, text = text })
    while #run.logs > 120 do table.remove(run.logs) end
end

function State.Save(profile, draft, run)
    local payload = { profile = profile, draft = draft, run = run }
    local file = File("jiaye_save.json", FILE_WRITE)
    if not file:IsOpen() then return false, "无法写入本地存档。" end
    file:WriteString(cjson.encode(payload)); file:Close()
    return true, "存档已写入当前项目与当前用户的本地空间。"
end

function State.Load()
    if not fileSystem:FileExists("jiaye_save.json") then return nil, "尚无本地存档。" end
    local file = File("jiaye_save.json", FILE_READ)
    if not file:IsOpen() then return nil, "无法读取本地存档。" end
    local raw = file:ReadString(); file:Close()
    local ok, value = pcall(cjson.decode, raw)
    if not ok or type(value) ~= "table" then return nil, "存档格式无效，未覆盖当前进度。" end
    return value, "已读取最近存档。"
end

function State.Import(raw)
    local ok, value = pcall(cjson.decode, raw)
    if not ok or type(value) ~= "table" or type(value.profile) ~= "table" or type(value.draft) ~= "table" then
        return nil, "备份格式无效，未覆盖当前进度。"
    end
    value.profile.unlockedRelicIds = value.profile.unlockedRelicIds or { book = true, ruler = true, letter = true }
    value.profile.endingRecords = value.profile.endingRecords or {}
    return value, "备份结构有效，可安全载入。"
end

function State.Export(profile, draft, run)
    local raw = cjson.encode({ profile = profile, draft = draft, run = run })
    local file = File("jiaye_export.json", FILE_WRITE)
    if file:IsOpen() then file:WriteString(raw); file:Close() end
    return raw
end

return State
