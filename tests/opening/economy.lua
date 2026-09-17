local Economy = require "Jiaye.Economy"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"
local Data = require "Jiaye.Data"

local function Same(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not Same(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function NewRun()
    local run, issues = State.NewRun(State.NewDraft(), State.NewProfile())
    assert(run, table.concat(issues or {}, " "))
    return run
end

return function()
    local results = {}

    do
        local run = NewRun()
        local before = State.Copy(run)
        local preview = Economy.Preview(run)
        local settledRun = State.Copy(run)
        local settled = Economy.Settle(settledRun)
        assert(Same(run, before), "预估不应修改草案生成的运行状态")
        assert(Same(preview, settled), "预估账本必须与同一状态的正式结算一致")
        assert(preview.income == 29 and preview.training == 16 and preview.livingExpense == 14)
        assert(preview.landGrain == 4 and preview.netMoney == -1 and preview.netGrain == 5)
        table.insert(results, { id = "preview", income = preview.income, netMoney = preview.netMoney, netGrain = preview.netGrain })
    end

    do
        local profile = State.NewProfile()
        local run = NewRun()
        run.originId = "gentry"
        run.reputation = 25
        local expected = Economy.Preview(run)
        assert(Simulation.AdvanceYear(run, profile))
        assert(Same(run.lastLedger, expected), "年度推进应记录经济内核的同源账本")
        assert(run.reputation == 26, "旧日名门每户每年只能增加一次声望")
        table.insert(results, { id = "advance", reputation = run.reputation, ledger = run.lastLedger })
    end

    do
        local run = NewRun()
        run.money, run.grain = 0, 0
        run.metrics.foodYears, run.metrics.stable = 7, 5
        for _, member in ipairs(run.members) do member.jobId = "play" end
        local ledger = Economy.Settle(run)
        assert(not ledger.foodSatisfied and not ledger.moneySatisfied)
        assert(ledger.foodShortfall == 3 and ledger.boughtGrain == 0 and ledger.foodCost == 0)
        assert(run.metrics.foodYears == 0 and run.metrics.stable == 0)
        table.insert(results, { id = "shortage", shortfall = ledger.foodShortfall, foodYears = run.metrics.foodYears, stable = run.metrics.stable })
    end

    do
        local draft = State.NewDraft()
        draft.originId, draft.tieId = "gentry", "neighbor"
        draft.money, draft.grain, draft.land, draft.homeId = 0, 0, 0, "rented"
        local run, issues = State.NewRun(draft, State.NewProfile())
        assert(run, table.concat(issues or {}, " "))
        assert(run.reputation == 37, "旧日名门与乡里相熟的初始声望必须独立叠加")

        local tradeDraft = State.NewDraft()
        tradeDraft.originId, tradeDraft.tieId, tradeDraft.placeId = "merchant", "partner", "port"
        tradeDraft.money, tradeDraft.grain, tradeDraft.land = 0, 0, 0
        tradeDraft.members[1].jobId = "trade"
        local tradeRun, tradeIssues = State.NewRun(tradeDraft, State.NewProfile())
        assert(tradeRun, table.concat(tradeIssues or {}, " "))
        local ledger = Economy.Preview(tradeRun)
        local tradeRow
        for _, row in ipairs(ledger.members) do if row.memberId == 1 then tradeRow = row end end
        assert(tradeRow and tradeRow.money == 36, "商埠、行商后裔和商路故交必须按顺序叠加经商收入")
        table.insert(results, { id = "stacking", reputation = run.reputation, tradeIncome = tradeRow.money })
    end

    do
        local run = NewRun()
        local beforeMoney, beforeLand = run.money, run.land
        assert(Simulation.BuyAsset(run, "land"))
        assert(run.money == beforeMoney - Data.RuntimeAssetCosts.land and run.land == beforeLand + 1,
            "运行期置办必须读取统一的既有价格表")

        local invalid = State.NewDraft()
        invalid.money = invalid.money + 1
        local before = State.Copy(invalid)
        local started, issues = State.NewRun(invalid, State.NewProfile())
        assert(not started and #issues > 0 and Same(invalid, before), "非步进家底必须被拒绝且草案不得被静默改写")
        table.insert(results, { id = "price_and_reject", landCost = Data.RuntimeAssetCosts.land, invalidDraftPreserved = true })
    end

    return results
end
