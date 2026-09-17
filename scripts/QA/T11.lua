-- T11 隔离整合验收；真实 File、cjson、UI 与生产模块，玩家保存不动。
---@diagnostic disable: assign-type-mismatch, undefined-global
local UI = require "urhox-libs/UI"
local nativeFile, nativeFS = File, fileSystem

local function isolatedPath(path)
    if path == "jiaye_save.json" or path == "jiaye_save.backup.json" or path == "jiaye_export.json" then return "t11_qa_" .. path end
    return path
end

File = function(path, mode) return nativeFile(isolatedPath(path), mode) end
fileSystem = { FileExists = function(_, path) return nativeFS:FileExists(isolatedPath(path)) end }

local App = require "Jiaye.App"
local Opening = require "Jiaye.Opening"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"

local function adults(members, livingOnly)
    local result = {}
    for _, member in ipairs(members) do
        if member.age >= 18 and (not livingOnly or member.alive) then table.insert(result, member) end
    end
    return result
end

local function same(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not same(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function generatedDraft(profile)
    for seed = 1, 4096 do
        local draft = Opening.Generate(profile, seed, "mortal")
        if draft then
            local members = adults(draft.members)
            if #members >= 2 and members[1].age <= 44 and members[2].age <= 44 and draft.money >= 60 and draft.grain >= 12 then return draft end
        end
    end
    error("未找到可完成整合验收的合法家庭。")
end

local function resolvePending(run, profile)
    for _ = 1, 128 do
        local pending = Simulation.PendingEvents(run)
        if #pending == 0 then return end
        local event = pending[1]
        if event.type == "leader" then
            local candidate = adults(run.members, true)[1]
            assert(candidate and Simulation.ResolveLeaderEvent(run, event.instanceId, candidate.id))
        else
            local ok, message = Simulation.ResolveEvent(run, event.instanceId, "defer", profile)
            assert(ok, message)
        end
    end
    error("待决家事未能收束。")
end

local function verify()
    local profile = State.NewProfile()
    local draft = generatedDraft(profile)
    local run, issues = State.NewRun(draft, profile)
    assert(run, table.concat(issues or {}, "；"))
    assert(State.Save(profile, draft, run))

    local openingApp = App.New()
    assert(openingApp.run and openingApp.run.runId == run.runId)
    openingApp.gameTab = "family"; openingApp:Render()

    local family = adults(run.members, true)
    for _, member in ipairs(family) do
        assert(Simulation.SetJob(run, member.id, "farm"))
        assert(Simulation.SetBirthPlan(run, member.id, false))
    end
    local firstLeader = run.leaderId
    for year = 1, 10 do
        resolvePending(run, profile)
        assert(Simulation.AdvanceYear(run, profile))
        if year == 1 then
            local successor = nil
            for _, member in ipairs(adults(run.members, true)) do if member.id ~= firstLeader then successor = member; break end end
            assert(successor and Simulation.AppointLeader(run, successor.id, "T11 家业交接"))
        end
    end
    assert(Simulation.IsEndingReady(run, "peaceful") and run.ending == nil)
    assert(Simulation.ClaimEnding(run, "peaceful", profile))
    assert(run.ending and run.ending.id == "peaceful" and #profile.endingRecords == 1 and #Simulation.PendingEvents(run) == 0)

    local before = State.Copy(run)
    assert(not Simulation.AdvanceYear(run, profile) and same(before, run))
    assert(State.Save(profile, draft, run))
    local raw = assert(State.Export(profile, draft, run))
    local candidate = assert(State.PreflightImport(raw))
    assert(candidate.run.ending.id == "peaceful" and #candidate.profile.endingRecords == 1)

    local reviewApp = App.New()
    assert(reviewApp.run and reviewApp.run.ending and reviewApp.profile.endingRecords[1].id == "peaceful")
    reviewApp.gameTab = "family"; reviewApp:Render()
    reviewApp.gameTab = "history"; reviewApp.historySection = "endings"; reviewApp:Render()

    local collapseProfile = State.NewProfile()
    local collapseDraft = generatedDraft(collapseProfile)
    local collapseRun = assert(State.NewRun(collapseDraft, collapseProfile))
    for _, member in ipairs(collapseRun.members) do member.age, member.health, member.jobId, member.birthPlan = 30, 100, "play", false end
    collapseRun.money, collapseRun.grain, collapseRun.land = 0, 0, 0
    assert(Simulation.AdvanceYear(collapseRun, collapseProfile))
    assert(collapseRun.ending and collapseRun.ending.id == "collapse" and collapseRun.ending.automaticTrigger == "resources_exhausted"
        and collapseRun.lastLedger.resourcesExhausted and #collapseProfile.endingRecords == 1
        and collapseProfile.endingRecords[1].automaticTrigger == "resources_exhausted")
    local collapseBefore = State.Copy(collapseRun)
    assert(not Simulation.SetJob(collapseRun, collapseRun.members[1].id, "farm") and same(collapseBefore, collapseRun))
    assert(State.Save(collapseProfile, collapseDraft, collapseRun))
    local collapsed = assert(State.Load())
    assert(collapsed.run.ending.id == "collapse" and collapsed.run.ending.automaticTrigger == "resources_exhausted"
        and collapsed.profile.endingRecords[1].factId == collapseRun.ending.factId
        and collapsed.profile.endingRecords[1].automaticTrigger == "resources_exhausted")
    local collapseApp = App.New()
    assert(collapseApp.run and collapseApp.run.ending and collapseApp.run.ending.id == "collapse")
    collapseApp.gameTab = "family"; collapseApp:Render()
    collapseApp.gameTab = "history"; collapseApp.historySection = "annals"; collapseApp:Render()
    return { family = draft.family, members = #draft.members, years = run.yearIndex, ending = run.ending.id, facts = #run.facts, ledgers = #run.annualLedgers,
        collapseEnding = collapsed.run.ending.id, collapseTrigger = collapsed.run.ending.automaticTrigger, collapseRevision = collapsed.saveRevision }
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    local ok, result = pcall(verify)
    if not ok then
        print("T11_QA_FAIL " .. tostring(result))
        UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", padding = 18, children = { UI.Label { text = "T11 验收失败\n" .. tostring(result), whiteSpace = "normal" } } })
        return
    end
    print("T11_QA_PASS 生成家庭、年度交接、终章、家道散尽、只读、保存与家史重载通过 " .. cjson.encode(result))
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", padding = 18, children = {
        UI.Label { text = "T11 真实引擎整合验收通过", fontSize = 24 },
        UI.Label { text = "· 生成合法家庭后入局保存，年度结算、交接与家史持续累积\n· 年末钱粮同归零时自动写入家道终局，人物经历继续可读\n· 重载后终章、条件记录与家史来自同一份保存", whiteSpace = "normal", lineHeight = 1.65 },
    } })
end

function Stop()
    UI.Shutdown()
end
