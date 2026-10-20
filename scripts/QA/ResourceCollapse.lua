local Data = require "Jiaye.Data"
local Economy = require "Jiaye.Economy"
local OriginState = require "Jiaye.OriginState"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"

local QA = {}

local function NewHousehold(current)
    local profile, draft = State.NewProfile(), State.NewDraft()
    draft.selectedRelicIds = {}
    if current then
        draft.rulesVersion = Data.RULES_VERSION
        draft.backgroundId = assert(Data.BackgroundForOrigin(draft.originId)).id
        draft.relicRulesVersion = "1.2"
        draft.selectedRelicFormIds = {}
        draft.relicUsers = {}
        draft.originRulesVersion = OriginState.VERSION
    end
    local run, issues = State.NewRun(draft, profile)
    assert(run, table.concat(issues or {}, "；"))
    run.land = 0
    for _, member in ipairs(run.members) do
        assert(Simulation.SetJob(run, member.id, "rest"))
        member.birthPlan = false
    end
    return run, profile, draft
end

function QA.Run()
    local results = {}
    local saved = {}
    local cases = {
        { id = "银两单项归零", money = 14, grain = 40, endMoney = 0, endGrain = 33, collapsed = true },
        { id = "存粮单项归零", money = 100, grain = 7, endMoney = 86, endGrain = 0, collapsed = true },
        { id = "卖尽余粮仍负债", money = 0, grain = 9, endMoney = -10, endGrain = 0, sold = 2, collapsed = true },
        { id = "已有负22两继续结算", money = -22, grain = 0, endMoney = 0, endGrain = 0, collapsed = true },
        { id = "余银不足补购口粮", money = 15, grain = 6, endMoney = 1, endGrain = 0, foodSatisfied = false, collapsed = true },
        { id = "卖粮后钱粮均有余", money = 1, grain = 15, endMoney = 1, endGrain = 1, sold = 7, collapsed = false },
        { id = "正常钱粮储备", money = 100, grain = 40, endMoney = 86, endGrain = 33, collapsed = false },
    }
    for _, current in ipairs({ false, true }) do
        for _, case in ipairs(cases) do
            local run, profile, draft = NewHousehold(current)
            run.money, run.grain = case.money, case.grain
            if case.money < 0 then assert(Simulation.IsFamilyCollapsed(run), "负数银两未命中破产条件。") end
            assert(Simulation.AdvanceYear(run, profile))
            local ledger = run.lastLedger
            assert(run.money == case.endMoney and run.grain == case.endGrain, case.id .. "：实际年度钱粮余额错误。")
            assert(ledger.resourcesExhausted == case.collapsed and Simulation.IsFamilyCollapsed(run) == case.collapsed
                and Simulation.IsEndingReady(run, "collapse") == case.collapsed, case.id .. "：破产判定不一致。")
            assert(run.annualLedgers[1].resourcesExhausted == case.collapsed, case.id .. "：家史账本判定不一致。")
            if case.sold then assert(ledger.grainSold == case.sold, case.id .. "：卖粮数量错误。") end
            if case.foodSatisfied ~= nil then assert(ledger.foodSatisfied == case.foodSatisfied, case.id .. "：补粮状态错误。") end
            if case.collapsed then
                local record = assert(run.ending, case.id .. "：缺少家道终局。")
                assert(record.id == "collapse" and record.automaticTrigger == "resources_exhausted" and #record.evidence == 3,
                    case.id .. "：终章触发来源或条件快照错误。")
                assert(record.evidence[1].current == run.money and record.evidence[2].current == run.grain
                    and (record.evidence[1].met or record.evidence[2].met or record.evidence[3].met), case.id .. "：终章未保留实际钱粮与满足条件。")
                assert(#profile.endingRecords == 1 and profile.endingRecords[1].factId == record.factId
                    and #Simulation.PendingEvents(run) == 0, case.id .. "：档案或事件关闭错误。")
                local revision = run.revision
                assert(not Simulation.AdvanceYear(run, profile) and run.revision == revision and #profile.endingRecords == 1,
                    case.id .. "：终局后仍可推进或重复写入。")
                if current and case.endMoney < 0 then saved = { run = run, profile = profile, draft = draft } end
            else
                assert(run.ending == nil and #profile.endingRecords == 0, case.id .. "：正常经营被提前结束。")
            end
            table.insert(results, { name = case.id, rules = current and "1.2＋背景机会" or "旧规则", money = run.money,
                grain = run.grain, collapsed = case.collapsed, foodSatisfied = ledger.foodSatisfied, grainSold = ledger.grainSold })
        end
    end
    assert(Data.Ending("collapse").automatic and #results == 14)
    assert(Economy.IsFamilyCollapsed({ money = 100, grain = -1 }), "负数存粮未命中破产条件。")
    return results, saved
end

return QA
