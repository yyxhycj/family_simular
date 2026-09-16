local Data = require "Jiaye.Data"
---@diagnostic disable: undefined-global -- UrhoX runtime injects File/fileSystem/cjson.

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
end

-- 两个交替存档位：只写非最新的一份，失败时保留上次可读进度。
---@type string[]
local SAVE_PATHS = { "jiaye_save.json", "jiaye_save.backup.json" }
---@type string?
local failedSavePath = nil

local function ReadFile(path)
    local file = File(path, FILE_READ)
    if not file:IsOpen() then return nil end
    local ok, raw = pcall(function() return file:ReadString() end)
    file:Close()
    return ok and raw or nil
end

local function ReadSlot(path)
    -- 本进程未确认成功的候选不参与选档；首次保存失败后仍能原地重试。
    -- 重启后没有此标记，仍按磁盘内容检查，绝不自行覆盖未知坏档。
    if path == failedSavePath then return nil, "unconfirmed" end
    if not fileSystem:FileExists(path) then return nil, "missing" end
    local raw = ReadFile(path)
    if not raw then return nil, "unreadable" end
    local ok, value = pcall(cjson.decode, raw)
    if not ok or type(value) ~= "table" then return nil, "invalid" end
    local profile, draft, run = value.profile, value.draft, value.run
    -- 这里只识别当前格式的必要容器；完整旧版迁移、引用校验留在 T10。
    if type(profile) ~= "table" or profile.schemaVersion ~= 1
        or type(profile.unlockedRelicIds) ~= "table" or type(profile.endingRecords) ~= "table"
        or type(draft) ~= "table" or type(draft.members) ~= "table" or type(draft.selectedRelicIds) ~= "table"
        or (run ~= nil and (type(run) ~= "table" or run.schemaVersion ~= 1
            or type(run.members) ~= "table" or type(run.logs) ~= "table" or type(run.events) ~= "table"
            or type(run.leaderTerms) ~= "table" or type(run.relicInstances) ~= "table")) then
        return nil, "invalid"
    end
    local revision = value.saveRevision or 0 -- 兼容现有未编号存档。
    if type(revision) ~= "number" or revision < 0 or revision ~= math.floor(revision) or revision == math.huge then return nil, "invalid" end
    value.saveRevision = revision
    return value, "ok"
end

local function LatestSave()
    local latest, index, problem, unreadable = nil, nil, false, false
    for slot, path in ipairs(SAVE_PATHS) do
        local value, status = ReadSlot(path)
        if value and (not latest or value.saveRevision > latest.saveRevision) then latest, index = value, slot end
        if status == "invalid" or status == "unreadable" then problem = true end
        if status == "unreadable" then unreadable = true end
    end
    return latest, index, problem, unreadable
end

local function WriteVerified(path, raw)
    local file = File(path, FILE_WRITE)
    if not file:IsOpen() then return false end
    local ok, written = pcall(function() return file:WriteString(raw) end)
    file:Close()
    -- UrhoX WriteString 返回 boolean，不能把 0 或任意 truthy 值当成功。
    return ok and written == true and ReadFile(path) == raw
end

function State.Save(profile, draft, run)
    local previous, index, problem, unreadable = LatestSave()
    if unreadable or (problem and not previous) then return false, "旧存档无法安全读取，已停止覆盖；请保留原文件并导出当前进度。" end
    local payload = { profile = profile, draft = draft, run = run, saveRevision = (previous and previous.saveRevision or 0) + 1 }
    local encoded, raw = pcall(cjson.encode, payload)
    if not encoded then return false, "存档编码失败，当前进度仍在内存中。" end
    local targetPath = index == 1 and SAVE_PATHS[2] or SAVE_PATHS[1]
    if not WriteVerified(targetPath, raw) then
        failedSavePath = targetPath
        return false, "存档写入或回读失败，当前进度仍在内存中，已有可读存档未覆盖；请重试保存或导出。"
    end
    failedSavePath = nil
    return true, "进度已保存并回读核对，上次可读存档仍保留。"
end

function State.Load()
    local value, _, problem = LatestSave()
    if value then
        return value, problem and "一份存档不可读，已恢复另一份可读进度；请核对年份。" or "已读取最近存档。", problem and "recovered" or "ok"
    end
    return nil, problem and "本地存档不可读，已停止开新局以保护旧进度；请保留原文件。" or "尚无本地存档。", problem and "invalid" or "missing"
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
    local ok, raw = pcall(cjson.encode, { profile = profile, draft = draft, run = run })
    if not ok then return nil, "备份编码失败，未导出。" end
    if not WriteVerified("jiaye_export.json", raw) then return nil, "备份写入或回读失败，未确认导出成功。" end
    return raw, "备份已写入 jiaye_export.json 并回读核对。"
end

return State
