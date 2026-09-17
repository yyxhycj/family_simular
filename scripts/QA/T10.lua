-- T10 隔离引擎验收；正式 main.lua 不引用。真实 File/cjson/UI，原家谱不动。
---@diagnostic disable: assign-type-mismatch, undefined-global
local UI = require "urhox-libs/UI"
local nativeFile, nativeFS = File, fileSystem

local function isolatedPath(path)
    if path == "jiaye_save.json" or path == "jiaye_save.backup.json" or path == "jiaye_export.json" then return "t10_qa_" .. path end
    return path
end

File = function(path, mode) return nativeFile(isolatedPath(path), mode) end
fileSystem = { FileExists = function(_, path) return nativeFS:FileExists(isolatedPath(path)) end }

local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local App = require "Jiaye.App"

local function legacyPayload()
    local draft = {
        family = "林", world = "mortal", era = "peace", calendar = 72, origin = "artisan", place = "village", habit = "none", tie = "none",
        money = 80, grain = 24, land = 1, home = "simple", workshop = false, shop = false, relics = { "ruler" }, leader = 1, seed = 72831, nextId = 5,
        members = {
            { id = 1, name = "林成", sex = "男", age = 42, parents = {}, spouse = 2, talent = 2, focus = "skill", experience = "craft", trait = "踏实", job = "craft" },
            { id = 2, name = "许青", sex = "女", age = 40, parents = {}, spouse = 1, talent = 2, focus = "general", experience = "basic", trait = "细致", job = "farm" },
            { id = 3, name = "林芸", sex = "女", age = 18, parents = { 1, 2 }, spouse = nil, talent = 3, focus = "medicine", experience = "none", trait = "仁厚", job = "medical" },
            { id = 4, name = "林安", sex = "男", age = 10, parents = { 1, 2 }, spouse = nil, talent = 3, focus = "learn", experience = "none", trait = "好奇", job = "study" },
        },
    }
    local function member(source)
        local values = source.experience == "craft" and { learn = 15, skill = 50, medicine = 0, trade = 15, martial = 10 }
            or (source.experience == "basic" and { learn = 25, skill = 25, medicine = 10, trade = 10, martial = 10 } or { learn = 10, skill = 10, medicine = 0, trade = 10, martial = 10 })
        return {
            id = source.id, name = source.name, sex = source.sex, age = source.age, parents = source.parents, spouse = source.spouse,
            talent = source.talent, focus = source.focus, experience = source.experience, trait = source.trait, job = source.job,
            alive = true, health = 86, learn = values.learn, skill = values.skill, medicine = values.medicine, trade = values.trade, martial = values.martial,
            gen = source.id > 2 and 2 or 1, jobYears = {}, birthPlan = true, lastBirth = -5, bio = { { year = 0, text = "V5 原始人生记录。" } }, examPassed = false,
        }
    end
    local members = {}
    for _, source in ipairs(draft.members) do table.insert(members, member(source)) end
    return {
        schema = 3,
        profile = { unlocked = { "book", "ruler", "letter", "plan" }, records = { { id = "plan", reason = "旧尺查访", year = 2 } }, endings = { { id = "peaceful", title = "炊烟未断", year = 6 } } },
        draft = draft,
        game = {
            version = 3, runId = "v5-engine-run", seed = 72831, rng = 146813, config = draft, family = "林", calendar = 74, elapsed = 2,
            era = "peace", eraSince = 0, place = "village", money = 58, grain = 20, land = 1, home = "simple", workshop = false, shop = false,
            reputation = 10, members = members, leader = 1, leaders = { { id = 1, start = 0, ["end"] = nil, reason = "V5 开局任命" } }, nextId = 5,
            relics = { { id = "ruler", custodian = 1, status = "owned", phase = 1, due = 2, route = "fast", history = { { year = 0, text = "开始查访木尺。" } } } },
            events = { { id = "relic-ruler-1", type = "relicFinish", relic = "ruler" } }, logs = { { year = 0, type = "开篇", title = "林家落脚", body = "V5 年鉴原文。", effects = {} } },
            metrics = { stable = 2, foodYears = 2, aid = 1, migrations = 0, lastMove = 0 }, flags = {}, ended = nil,
        },
    }
end

local function verify()
    local raw = cjson.encode(legacyPayload())
    local candidate, message, status = State.PreflightImport(raw)
    assert(status == "ready" and message:find("V5") and candidate.migratedFrom == "v5-schema-3")
    assert(candidate.profile.unlockedRelicIds.plan and candidate.run.events[1].type == "relic_resolution")
    assert(candidate.run.rngState == 146814 and candidate.draft.members[2].nameSource == "custom")
    assert(State.CommitImport(candidate))
    local saved = assert(State.Load())
    local revision = saved.saveRevision
    local duplicate, _, duplicateStatus = State.CommitImport(candidate)
    assert(duplicate and duplicateStatus == "duplicate" and State.Load().saveRevision == revision)
    local profile, draft = saved.profile, saved.draft
    local run = saved.run
    assert(run.events[1].status == "pending" and run.relicInstances[1].status == "awaiting_resolution")
    local exportRaw = assert(State.Export(profile, draft, run))
    local restored = assert(State.PreflightImport(exportRaw))
    assert(restored.run.rngState == run.rngState and restored.run.events[1].instanceId == run.events[1].instanceId)
    local bad = State.Copy(restored); bad.run.leaderId = 999
    assert(not State.PreflightImport(cjson.encode(bad)))
    assert(State.Load().run.leaderId == run.leaderId)
    local app = App.New(); assert(app.run and app.run.events[1].type == "relic_resolution")
    app.gameTab = "family"; app:Render()
    return { revision = revision, rng = run.rngState, pending = run.events[1].type, logs = #run.logs }
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    local ok, result = pcall(verify)
    if not ok then
        print("T10_QA_FAIL " .. tostring(result))
        UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", padding = 18, children = { UI.Label { text = "T10 验收失败\n" .. tostring(result), whiteSpace = "normal" } } })
        return
    end
    print("T10_QA_PASS V5 显式迁移、引用校验、原子导入、重复确认与待决/RNG 回读通过 " .. cjson.encode(result))
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", padding = 18, children = {
        UI.Label { text = "T10 真实引擎验收通过", fontSize = 24 },
        UI.Label { text = "· V5 存档先预演，再确认写入；外姓与待决木尺调查保留\n· 迁入后 RNG、待决事件、收藏与家史从同一存档回读\n· 重复确认不重复写入；坏引用不污染现有进度", whiteSpace = "normal", lineHeight = 1.65 },
    } })
end

function Stop()
    UI.Shutdown()
end
