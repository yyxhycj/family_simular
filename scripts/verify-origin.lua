local UI = require "urhox-libs/UI"
local Visual = require "Jiaye.Visual"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Economy = require "Jiaye.Economy"
local OriginState = require "Jiaye.OriginState"
local Origin = require "Jiaye.OriginSystem"
local App = require "Jiaye.App"

local function Family(originId, job, experience)
    local profile = State.NewProfile()
    ---@type table
    local draft = State.NewDraft()
    draft.family = "验收"
    draft.rulesVersion, draft.relicRulesVersion, draft.originRulesVersion = 2, "1.2", OriginState.VERSION
    draft.artVersion = "ink_v2_review"
    draft.originId = originId
    draft.members = { draft.members[1], draft.members[2] }
    for _, member in ipairs(draft.members) do
        member.jobId, member.experienceId, member.artVersion = job, experience, draft.artVersion
    end
    draft.selectedRelicIds = nil
    draft.selectedRelicFormIds, draft.relicUsers = { "ruler.1" }, { ["ruler.1"] = 1 }
    local run, issues = State.NewRun(draft, profile)
    assert(run, issues and table.concat(issues, "；"))
    for _, person in ipairs(run.members) do assert(Simulation.SetBirthPlan(run, person.id, false)) end
    return profile, draft, run
end

function Start()
    local original = State.Load()
    if original and original.run then
        print("[背景机会验收] 玩家存档只读：" .. original.draft.family .. "氏，第" .. tostring(original.run.yearIndex) .. "年，银" .. tostring(original.run.money) .. "粮" .. tostring(original.run.grain))
    end
    State.UseVerificationStorage("origin")
    local profile, draft, run = Family("artisan", "craft", "craft")
    assert(Origin.Execute(run, "start", { memberId = 1 }))
    assert(Origin.Execute(run, "pause"))
    assert(State.Save(profile, draft, run))
    local saved = assert(State.Load())
    profile, draft, run = saved.profile, saved.draft, saved.run
    assert(run.originOpportunity.status == "paused")
    assert(Origin.Execute(run, "resume", { memberId = 2 }))
    local preview = Economy.Preview(run)
    assert(Simulation.AdvanceYear(run, profile))
    assert(run.originOpportunity.status == "ready" and run.money == preview.money)
    assert(Origin.Execute(run, "take_cash"))
    assert(run.money == preview.money + 22 and not Origin.Execute(run, "take_cash"))
    assert(State.Save(profile, draft, run))
    saved = assert(State.Load())
    local raw = assert(State.Export(saved.profile, saved.draft, saved.run))
    local imported = assert(State.PreflightImport(raw))
    assert(imported.run.originOpportunity.status == "settled" and imported.run.artVersion == "ink_v2_review")
    print("[背景机会验收] 修缮付8→暂停保存读取→换人免费恢复→真实年度→领取22→重复拒绝→保存读取导出校验通过。")

    profile, draft, run = Family("scholar", "study", "basic")
    assert(Origin.Execute(run, "borrow", { memberId = 1 }))
    local deadline = run.originOpportunity.dueAfterYear
    assert(Simulation.AdvanceYear(run, profile))
    assert(run.originOpportunity.benefits.scroll.remainingUses == 1)
    assert(Origin.Execute(run, "assign_reader", { memberId = 2 }))
    assert(State.Save(profile, draft, run))
    saved = assert(State.Load())
    profile, draft, run = saved.profile, saved.draft, saved.run
    assert(run.originOpportunity.dueAfterYear == deadline and run.originOpportunity.benefits.scroll.remainingUses == 1)
    local money = run.money
    assert(Origin.Execute(run, "return"))
    assert(run.money == money + 6 and not Origin.Execute(run, "return"))
    print("[背景机会验收] 借卷付8→实际读书1次→换读者保存读取→期限次数不重置→归还退6且不重复通过。")

    profile, draft, run = Family("artisan", "craft", "craft")
    assert(State.Save(profile, draft, run))
    UI.Init({ theme = Visual.Theme(), scale = UI.Scale.DPR })
    local app = App.New()
    app.screen, app.gameTab = "game", "family"
    app:Render()
    print("[背景机会验收] 已打开可操作的水墨家族页面；所有操作使用 jiaye_origin_verification 专属存档。")
end

function Stop()
    UI.Shutdown()
end
