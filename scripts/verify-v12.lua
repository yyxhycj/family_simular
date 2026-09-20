local UI = require "urhox-libs/UI"
local Visual = require "Jiaye.Visual"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Relics = require "Jiaye.RelicState"
local System = require "Jiaye.RelicSystem"
local App = require "Jiaye.App"

function Start()
    State.UseVerificationStorage()
    local profile = State.NewProfile()
    ---@type table
    local draft = State.NewDraft()
    draft.rulesVersion, draft.relicRulesVersion = 2, "1.2"
    draft.family = "验收"
    draft.members = { draft.members[1], draft.members[2] }
    draft.members[2].experienceId, draft.members[2].jobId = "craft", "craft"
    draft.selectedRelicIds = nil
    draft.selectedRelicFormIds, draft.relicUsers = { "ruler.1" }, { ["ruler.1"] = 1 }
    local run = assert(State.NewRun(draft, profile))
    for _, person in ipairs(run.members) do assert(Simulation.SetBirthPlan(run, person.id, false)) end
    local function advance()
        for _, event in ipairs(Simulation.PendingEvents(run)) do assert(Simulation.ResolveEvent(run, event.instanceId, "defer", profile)) end
        assert(Simulation.AdvanceYear(run, profile))
    end
    local rulerId = Relics.Primary(run, "ruler").instanceId
    assert(System.Start(run, profile, "ruler.trace_mark", {instanceId = rulerId, executorId = 1, route = "fast"}))
    local taskId = Relics.Find(run, rulerId).taskId
    assert(System.Pause(run, taskId))
    assert(State.Save(profile, draft, run))
    local restored = assert(State.Load())
    profile, draft, run = restored.profile, restored.draft, restored.run
    assert(run.relicTasks[1].id == taskId and run.relicTasks[1].status == "paused_manual")
    assert(System.Resume(run, taskId, {executorId = 2}))
    advance()
    assert(Relics.Find(run, rulerId).formId == "ruler.2")
    assert(System.Start(run, profile, "ruler.copy_plan", {instanceId = rulerId, executorId = 2}))
    local planId = Relics.Primary(run, "plan").instanceId
    assert(System.AssignUser(run, rulerId, 2))
    assert(System.AssignUser(run, planId, 2))
    assert(System.Start(run, profile, "plan.small_repair", {instanceId = planId, executorId = 2, attachedInstanceIds = {planId, rulerId}}))
    advance(); advance(); advance()
    assert(System.Start(run, profile, "plan.upgrade_2", {instanceId = planId, executorId = 2}))
    advance()
    assert(State.Save(profile, draft, run))
    restored = assert(State.Load())
    assert(Relics.Find(restored.run, planId).formId == "plan.2")
    assert(#restored.run.relicProjectFacts == 2 and restored.profile.unlockedRelicForms["plan.2"])
    local raw = assert(State.Export(restored.profile, restored.draft, restored.run))
    local imported = assert(State.PreflightImport(raw))
    assert(Relics.Find(imported.run, planId).formId == "plan.2")
    print("[家业1.2引擎验收] 真实任务→暂停保存读取→换人校准→誊图→工程→增订→保存读取→导出校验通过；使用专属验证文件。")
    UI.Init({theme = Visual.Theme(), scale = UI.Scale.DPR})
    local app = App.New()
    app.screen, app.gameTab = "game", "relics"
    app:Render()
end

function Stop()
    UI.Shutdown()
end
