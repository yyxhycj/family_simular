local Economy = require "Jiaye.Economy"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"

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

    return results
end
