local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"

local cases = {}

local function same(left, right) return cjson.encode(left) == cjson.encode(right) end

local function fresh()
    local profile, draft = State.NewProfile(), State.NewDraft()
    local run = assert(State.NewRun(draft, profile))
    return profile, draft, run
end

local function legacyPayload()
    return {
        schema = 3,
        profile = { unlocked = { "book", "ruler", "letter", "plan" }, records = { { id = "plan", reason = "旧尺查访", year = 2 } }, endings = { { id = "peaceful", title = "炊烟未断", year = 6 } } },
        draft = {
            family = "林", world = "mortal", era = "peace", calendar = 72, origin = "artisan", place = "village", habit = "none", tie = "none",
            money = 80, grain = 24, land = 1, home = "simple", workshop = false, shop = false, relics = { "ruler" }, leader = 1, seed = 72831, nextId = 5,
            members = {
                { id = 1, name = "林成", sex = "男", age = 42, parents = {}, spouse = 2, talent = 2, focus = "skill", experience = "craft", trait = "踏实", job = "craft" },
                { id = 2, name = "许青", sex = "女", age = 40, parents = {}, spouse = 1, talent = 2, focus = "general", experience = "basic", trait = "细致", job = "farm" },
                { id = 3, name = "林芸", sex = "女", age = 18, parents = { 1, 2 }, spouse = nil, talent = 3, focus = "medicine", experience = "none", trait = "仁厚", job = "medical" },
                { id = 4, name = "林安", sex = "男", age = 10, parents = { 1, 2 }, spouse = nil, talent = 3, focus = "learn", experience = "none", trait = "好奇", job = "study" },
            },
        },
    }
end

local function legacyGame(payload)
    local members = {}
    for _, member in ipairs(payload.draft.members) do
        local experience = Data.Experience(member.experience)
        table.insert(members, {
            id = member.id, name = member.name, sex = member.sex, age = member.age, parents = member.parents, spouse = member.spouse,
            talent = member.talent, focus = member.focus, experience = member.experience, trait = member.trait, job = member.job,
            alive = true, health = 86, learn = experience.values.learn, skill = experience.values.skill, medicine = experience.values.medicine,
            trade = experience.values.trade, martial = experience.values.martial, gen = member.id > 2 and 2 or 1,
            jobYears = {}, birthPlan = true, lastBirth = -5, bio = { { year = 0, text = "V5 时代的原始人生记录。" } }, examPassed = false,
        })
    end
    return {
        version = 3, runId = "v5-long-run", seed = 72831, rng = 146813, config = payload.draft, family = "林", calendar = 74, elapsed = 2,
        era = "peace", eraSince = 0, place = "village", money = 58, grain = 20, land = 1, home = "simple", workshop = false, shop = false,
        reputation = 10, members = members, leader = 1, leaders = { { id = 1, start = 0, ["end"] = nil, reason = "V5 开局任命" } }, nextId = 5,
        relics = { { id = "ruler", custodian = 1, status = "owned", phase = 1, due = 2, route = "fast", history = { { year = 0, text = "开始查访木尺。" } } } },
        events = { { id = "relic-ruler-1", type = "relicFinish", relic = "ruler" } },
        logs = { { year = 0, type = "开篇", title = "林家落脚", body = "旧版年鉴记录。", effects = { "银钱 80 两" } }, { year = 2, type = "查访", title = "木尺有了回音", body = "等待决定。", effects = {} } },
        metrics = { stable = 2, foodYears = 2, aid = 1, migrations = 0, lastMove = 0 }, flags = {}, ended = nil,
    }
end

cases.current_roundtrip = function()
    local profile, draft, run = fresh()
    for index = 1, 151 do State.AddLog(run, "长局年鉴 " .. tostring(index)) end
    assert(Simulation.StartRelicInvestigation(run, "relic-1", "fast", 1))
    local beforeRng, beforeDue = run.rngState, run.relicInstances[1].dueYear
    assert(State.Save(profile, draft, run))
    local raw = assert(State.Export(profile, draft, run))
    local candidate, message, status = State.PreflightImport(raw)
    assert(status == "ready" and candidate and message:find("经营"))
    assert(candidate.run.rngState == beforeRng and candidate.run.relicInstances[1].dueYear == beforeDue)
    assert(#candidate.run.logs >= 151 and candidate.run.relicInstances[1].status == "investigating")
    assert(State.CommitImport(candidate))
    local saved = assert(State.Load())
    local revision = saved.saveRevision
    local duplicate, duplicateMessage, duplicateStatus = State.CommitImport(candidate)
    assert(duplicate and duplicateStatus == "duplicate" and duplicateMessage:find("已经导入"))
    local repeated = assert(State.Load())
    assert(repeated.saveRevision == revision and repeated.run.rngState == beforeRng and repeated.run.relicInstances[1].dueYear == beforeDue)
    return { history = #repeated.run.logs, rng = repeated.run.rngState, dueYear = repeated.run.relicInstances[1].dueYear, saveRevision = revision }
end

cases.v5_migration = function()
    local payload = legacyPayload()
    payload.game = legacyGame(payload)
    local candidate, message, status = State.PreflightImport(cjson.encode(payload))
    assert(status == "ready" and candidate and message:find("V5"))
    assert(candidate.migratedFrom == "v5-schema-3" and candidate.profile.unlockedRelicIds.plan)
    assert(candidate.draft.family == "林" and candidate.draft.members[2].name == "许青" and candidate.draft.members[2].nameSource == "custom")
    assert(candidate.run.yearIndex == 2 and candidate.run.money == 58 and #candidate.run.logs == 2)
    assert(candidate.run.events[1].type == "relic_resolution" and candidate.run.events[1].status == "pending")
    assert(candidate.run.relicInstances[1].status == "awaiting_resolution" and candidate.run.rngState == 146814)
    assert(State.CommitImport(candidate))
    local saved = assert(State.Load())
    assert(saved.run.events[1].type == "relic_resolution" and saved.profile.unlockedRelicIds.plan)
    return { family = saved.draft.family, logs = #saved.run.logs, pending = saved.run.events[1].type, rng = saved.run.rngState, unlockedPlan = saved.profile.unlockedRelicIds.plan }
end

cases.ended = function()
    local profile, draft, run = fresh()
    assert(Simulation.FinalizeEnding(run, Data.Ending("last"), profile))
    assert(State.Save(profile, draft, run))
    local candidate = assert(State.PreflightImport(assert(State.Export(profile, draft, run))))
    assert(candidate.run.ending and candidate.run.ending.id == "last" and #candidate.profile.endingRecords == 1)
    assert(State.CommitImport(candidate))
    local saved = assert(State.Load())
    assert(saved.run.ending.id == "last" and #saved.profile.endingRecords == 1)
    return { ending = saved.run.ending.id, records = #saved.profile.endingRecords }
end

cases.damaged = function()
    local profile, draft, run = fresh()
    assert(State.Save(profile, draft, run))
    local before = State.Copy(assert(State.Load()))
    assert(not State.PreflightImport("{broken"))
    local malformed = State.Copy(before)
    malformed.run.leaderId = 999
    assert(not State.PreflightImport(cjson.encode(malformed)))
    assert(same(before, assert(State.Load())))
    return { unchanged = true, family = before.draft.family }
end

cases.write_failure = function()
    local profile, draft, run = fresh()
    assert(State.Save(profile, draft, run))
    local before = State.Copy(assert(State.Load()))
    fault.mode = "write_false"
    local raw, message = State.Export(profile, draft, run)
    fault.mode = ""
    assert(raw == nil and message:find("未确认"))
    assert(same(before, assert(State.Load())))
    return { exportRejected = true, family = before.draft.family }
end

return cases
