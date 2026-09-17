-- T02 只验证草案、预算、预估与随机事务；不把整户生成或手机布局当作本步证据。
local App = require "Jiaye.App"
local Data = require "Jiaye.Data"
local Economy = require "Jiaye.Economy"
local Opening = require "Jiaye.Opening"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"

local function Same(left, right)
    return Opening.Equal(left, right)
end

local function NewRun(draft)
    local run, issues = State.NewRun(draft or State.NewDraft(), State.NewProfile())
    assert(run, table.concat(issues or {}, " "))
    return run
end

local function MemberLedger(ledger, id)
    for _, row in ipairs(ledger.members) do if row.memberId == id then return row end end
    return nil
end

return function()
    local profile = State.NewProfile()
    local results = {}

    do
        local atLimit = State.NewDraft()
        atLimit.money = 110
        assert(State.TotalPoints(atLimit) == Data.LIMIT and #State.ValidateDraft(atLimit, profile, false) == 0)
        assert(NewRun(atLimit).openingSnapshot.money == 110, "开始必须使用正在展示的草案快照")

        local overLimit = State.Copy(atLimit)
        overLimit.money = 120
        local beforeOver = State.Copy(overLimit)
        assert(State.TotalPoints(overLimit) == Data.LIMIT + 1 and not State.NewRun(overLimit, profile))
        assert(Same(overLimit, beforeOver), "超分拒绝不可静默降级草案")

        local invalidStep = State.Copy(atLimit)
        invalidStep.money = 111
        local beforeInvalid = State.Copy(invalidStep)
        assert(not State.NewRun(invalidStep, profile) and Same(invalidStep, beforeInvalid), "非步进家底不可开始或被自动取整")
        table.insert(results, { id = "budget", atLimit = Data.LIMIT, rejected = Data.LIMIT + 1, invalidDraftPreserved = true })
    end

    do
        local run = NewRun()
        local before = State.Copy(run)
        local preview = Economy.Preview(run)
        local settlementRun = State.Copy(run)
        local settled = Economy.Settle(settlementRun)
        assert(Same(run, before) and Same(preview, settled), "预估必须从同一结算核计算且不写入原状态")

        local reputationDraft = State.NewDraft()
        reputationDraft.originId, reputationDraft.tieId = "gentry", "neighbor"
        reputationDraft.money, reputationDraft.grain, reputationDraft.land, reputationDraft.homeId = 0, 0, 0, "rented"
        assert(NewRun(reputationDraft).reputation == 37, "来历和关系的初始效果必须独立叠加")

        local tradeDraft = State.NewDraft()
        tradeDraft.originId, tradeDraft.tieId, tradeDraft.placeId = "merchant", "partner", "port"
        tradeDraft.money, tradeDraft.grain, tradeDraft.land = 0, 0, 0
        tradeDraft.members[1].jobId = "trade"
        assert(MemberLedger(Economy.Preview(NewRun(tradeDraft)), 1).money == 36,
            "商埠、行商后裔与商路故交必须共同作用于同一笔收入")
        table.insert(results, { id = "preview_and_stacking", income = preview.income, netMoney = preview.netMoney, reputation = 37, tradeIncome = 36 })
    end

    do
        local run = NewRun()
        local beforeMoney, beforeLand = run.money, run.land
        assert(Simulation.BuyAsset(run, "land"))
        assert(run.money == beforeMoney - Data.RuntimeAssetCosts.land and run.land == beforeLand + 1,
            "运行期动作必须读取界面共用的既有价格表")
        table.insert(results, { id = "runtime_price", landCost = Data.RuntimeAssetCosts.land })
    end

    do
        local app = App.New()
        local beforeEstate = Opening.Snapshot(app.draft, "estate")
        app:RandomizePage("estate")
        assert(app.undo.estate, "本页随机应创建本页撤销记录")
        app:SetDraftField("world", "originId", "merchant")
        assert(app.undo.estate and app.undo.world == nil, "跨页手改不得清除其他页撤销")
        app:UndoPage("estate")
        assert(app.draft.originId == "merchant" and Same(Opening.Snapshot(app.draft, "estate"), beforeEstate),
            "撤销本页不得覆盖别页最新手改")

        app:RandomizePage("estate")
        app:SetDraftField("estate", "money", app.draft.money)
        assert(app.undo.estate == nil, "本页手改必须使旧撤销失效")
        table.insert(results, { id = "page_scope", crossPagePreserved = true, staleUndoDiscarded = true })
    end

    return results
end
