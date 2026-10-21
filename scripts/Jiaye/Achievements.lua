local Definitions = require "Jiaye.AchievementDefinitions"
local Data = require "Jiaye.Data"
local Rules = require "Jiaye.AchievementRules"

local A = {}

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

function A.EnsureProfile(profile)
    assert(profile.achievementVersion == nil or profile.achievementVersion == Definitions.VERSION, "成就存档版本未知。")
    profile.achievementVersion = Definitions.VERSION
    profile.achievements = profile.achievements or {}
    profile.achievementFamilies = profile.achievementFamilies or {}
    profile.achievementStories = profile.achievementStories or {}
end

function A.EnsureRun(run)
    if not run then return end
    if not run.achievementState then run.achievementState = { version = Definitions.VERSION, baselines = {} } end
    local state = run.achievementState
    assert(state.version == Definitions.VERSION and type(state.baselines) == "table", "本局成就经历结构无效。")
    for _, member in ipairs(run.members) do
        local key = tostring(member.id)
        if not state.baselines[key] then
            local stats, age, year, talent = member.stats, member.age, run.yearIndex, member.talent
            for _, original in ipairs(run.openingSnapshot.members) do
                if original.id == member.id then
                    stats = assert(Data.Experience(original.experienceId)).values
                    age, year, talent = original.age, 0, original.talent
                end
            end
            -- 新加入者以首次完整快照为历史依据，当前读档状态只作为今后成长的起点。
            for index = #run.annualLedgers, 1, -1 do
                local ledger = run.annualLedgers[index]
                for _, original in ipairs((ledger.yearStart or {}).members or {}) do
                    if original.id == member.id and original.stats and ledger.yearIndex - 1 < year then
                        stats, age, year, talent = original.stats, original.age, ledger.yearIndex - 1, original.talent
                    end
                end
            end
            state.baselines[key] = { stats = Copy(stats), age = age, year = year, talent = talent }
        end
    end
end

local function Integer(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end

function A.Validate(profile, run)
    if profile.achievementVersion ~= nil then
        if profile.achievementVersion ~= Definitions.VERSION or type(profile.achievements) ~= "table"
            or type(profile.achievementFamilies) ~= "table" or type(profile.achievementStories) ~= "table" then return false, "成就收藏结构无效。" end
        for id, record in pairs(profile.achievements) do
            local definition = Definitions.ById[id]
            if not definition or not definition.enabled or type(record) ~= "table" or record.id ~= id or record.version ~= Definitions.VERSION
                or type(record.runId) ~= "string" or record.runId == "" or not Integer(record.yearIndex)
                or type(record.evidence) ~= "table" or type(record.family) ~= "string" or type(record.worldId) ~= "string" then
                return false, "成就记录或达成依据无效。"
            end
        end
        for id, record in pairs(profile.achievementFamilies) do
            if type(id) ~= "string" or id == "" or type(record) ~= "table" or not Integer(record.years)
                or type(record.endings) ~= "table" or type(record.family) ~= "string" or type(record.worldId) ~= "string" then return false, "跨局家族记录无效。" end
            for endingId, completed in pairs(record.endings) do
                local ending = Data.Ending(endingId)
                if completed ~= true or not ending or ending.automatic then return false, "跨局发展终章记录无效。" end
            end
        end
        for id, record in pairs(profile.achievementStories) do
            if not Rules.Stories[id] or type(record) ~= "table" or type(record.runId) ~= "string"
                or not Integer(record.yearIndex) or type(record.nodes) ~= "table" or #record.nodes < 2 then return false, "故事收束记录无效。" end
        end
    end
    if run and run.achievementState then
        local state = run.achievementState
        if type(state) ~= "table" or state.version ~= Definitions.VERSION or type(state.baselines) ~= "table" then return false, "本局成就记录无效。" end
        for _, baseline in pairs(state.baselines) do
            if type(baseline) ~= "table" or type(baseline.stats) ~= "table" or not Integer(baseline.year)
                or baseline.year > run.yearIndex or not Integer(baseline.age) or not Data.Talents[baseline.talent] then return false, "人物成长起点无效。" end
            for _, stat in ipairs({ "learn", "skill", "medicine", "trade", "martial" }) do
                if type(baseline.stats[stat]) ~= "number" or baseline.stats[stat] ~= baseline.stats[stat]
                    or baseline.stats[stat] < 0 or baseline.stats[stat] > 100 then return false, "人物成长起点数值无效。" end
            end
        end
    end
    return true
end

local function Award(profile, definition, run, evidence)
    if profile.achievements[definition.id] then return false end
    local source = run or evidence
    profile.achievements[definition.id] = {
        id = definition.id, version = Definitions.VERSION, runId = source.runId,
        family = run and run.openingSnapshot.family or source.family, worldId = source.worldId,
        yearIndex = run and run.yearIndex or source.yearIndex, calendar = source.calendar,
        evidence = Copy(evidence), unlockedAt = os.time(), legacyBackfill = run and run.achievementState.legacyBackfill == true or nil,
    }
    return true
end

function A.Update(profile, run)
    local changed = profile.achievementVersion == nil or run and run.achievementState == nil or false
    A.EnsureProfile(profile)
    A.EnsureRun(run)
    local added = {}
    if run then
        local family = profile.achievementFamilies[run.runId]
        if not family then
            family = { family = run.openingSnapshot.family, worldId = run.worldId, years = 0, endings = {} }
            profile.achievementFamilies[run.runId] = family
            changed = true
        end
        if run.yearIndex > family.years then changed = true end
        if run.yearIndex >= family.years then family.calendar = run.calendar end
        family.years = math.max(family.years, run.yearIndex)
        if run.ending and run.ending.type == "development" and not run.ending.automatic and not family.endings[run.ending.id] then
            family.endings[run.ending.id] = true; changed = true
        end
    end
    local progress, stories = Rules.Evaluate(profile, run)
    for id, record in pairs(stories) do
        if not profile.achievementStories[id] then profile.achievementStories[id] = Copy(record); changed = true end
    end
    -- 故事收藏刚发生变化时，同一次提交即可达成跨局故事成就。
    progress[79], progress[80] = Rules.StoryProgress(profile)
    for _, definition in ipairs(Definitions.All) do
        local result = progress[definition.index]
        if definition.enabled and result and result.current >= result.target then
            if Award(profile, definition, run, result.evidence) then table.insert(added, definition.id) end
        end
    end
    if run and run.achievementState.legacyBackfill then run.achievementState.legacyBackfill = nil; changed = true end
    return added, changed or #added > 0
end

function A.Progress(profile, run)
    local progress = Rules.Evaluate(profile, run)
    return progress
end

function A.Merge(target, source)
    A.EnsureProfile(target)
    if not source or not source.achievementVersion then return false end
    assert(A.Validate(source), "合并来源的成就记录无效。")
    local changed = false
    for _, field in ipairs({ "achievements", "achievementStories" }) do
        for id, record in pairs(source[field]) do
            if not target[field][id] then target[field][id] = Copy(record); changed = true end
        end
    end
    for id, record in pairs(source.achievementFamilies) do
        local existing = target.achievementFamilies[id]
        if not existing then target.achievementFamilies[id] = Copy(record); changed = true
        else
            if record.years > existing.years then existing.years, existing.calendar = record.years, record.calendar; changed = true end
            for endingId in pairs(record.endings) do
                if not existing.endings[endingId] then existing.endings[endingId] = true; changed = true end
            end
        end
    end
    if #A.Update(target) > 0 then changed = true end
    return changed
end

function A.Visible(profile)
    local rows = {}
    for _, definition in ipairs(Definitions.All) do
        if definition.enabled and (not definition.hidden or (profile.achievements or {})[definition.id]) then table.insert(rows, definition) end
    end
    return rows
end

return A
