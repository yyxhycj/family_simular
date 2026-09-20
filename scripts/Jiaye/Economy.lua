-- 年初快照的确定性收支：正式年度与只读预估共用，价格和取整保持原规则。
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Economy = {}
local function HasRelic(run, id)
    for _, item in ipairs(run.relicInstances) do if item.definitionId == id and item.status ~= "sold" then return true end end
    return false
end

local function ApplyIncome(run, member, job, period, place)
    local baseMoney, money, grain = job.money or 0, job.money or 0, job.grain or 0
    local initialHealth = member.health
    local growth = { stat = job.stat, amount = 0, health = 0 }
    money = math.floor(money * period.wage)
    if member.jobId ~= "farm" then money = math.floor(money * (place.incomeMultiplier or 1)) end
    if member.jobId == "craft" and place.id == "mountain" then money = math.floor(money * 1.1) end
    if member.jobId == "doctor" and place.id == "mountain" then money = math.floor(money * 1.1) end
    if member.jobId == "guard" and place.id == "border" then money = math.floor(money * 1.2) end
    if member.jobId == "trade" and place.id == "port" then money = math.floor(money * 1.2) end
    if member.jobId == "trade" and run.originId == "merchant" then money = math.floor(money * 1.1) end
    if member.jobId == "guard" and run.originId == "military" then money = math.floor(money * 1.1) end
    if member.jobId == "trade" and run.tieId == "partner" then money = money + 3 end
    if member.jobId == "teach" and run.tieId == "teacher" then money = money + 2 end
    if member.jobId == "doctor" and run.tieId == "healer" then money = money + 2 end
    if member.jobId == "trade" then money = money + math.floor((member.stats.trade or 0) / 20) end
    if member.jobId == "farm" then grain = grain + (place.id == "village" and 2 or 0) + (place.farmGrainModifier or 0) + (run.originId == "plain" and 1 or 0) end
    run.money = run.money + money; run.grain = run.grain + grain
    if job.stat == "health" then
        local beforeHealth = member.health
        member.health = math.min(100, member.health + math.max(0, job.gain or 0))
        growth.health = member.health - beforeHealth
    elseif job.stat then
        local talent = Data.Talent(math.tointeger(member.talent) or 1)
        local gain = (job.gain or 0) + talent.gain
        if run.habitId == "education" and member.jobId == "study" then gain = gain + 1 end
        if place.id == "county" and member.jobId == "study" then gain = gain + 1 end
        if run.tieId == "teacher" and member.jobId == "study" then gain = gain + 1 end
        if run.tieId == "healer" and member.jobId == "medical" then gain = gain + 1 end
        if HasRelic(run, "notes") and (member.jobId == "medical" or member.jobId == "doctor") then gain = gain + 2 end
        if run.originId == "artisan" and (member.jobId == "apprentice" or member.jobId == "craft") then gain = gain + 1 end
        if run.originId == "scholar" and member.jobId == "study" then gain = gain + 2 end
        if run.originId == "military" and member.jobId == "train" then gain = gain + 2 end
        local beforeStat = member.stats[job.stat] or 0
        member.stats[job.stat] = math.min(100, beforeStat + math.max(0, gain))
        growth.amount = member.stats[job.stat] - beforeStat
        growth.gain = gain
    end
    if member.jobId == "home" then
        local beforeHealth = member.health
        member.health = math.min(100, member.health + 1)
        growth.stat = "health"; growth.health = member.health - beforeHealth
    end
    if member.jobId == "rest" then
        local recovery = (run.homeId == "estate" and 2 or run.homeId == "courtyard" and 1 or 0) + (run.habitId == "care" and 2 or 0)
        member.health = math.min(100, member.health + recovery)
        growth.stat = "health"; growth.health = member.health - initialHealth; growth.gain = (job.gain or 0) + recovery
    end
    return { baseMoney = baseMoney, money = money, grain = grain, growth = growth }
end

-- 只读岗位报价：复制完整 run 后复用正式收入与成长计算，不推进原局状态。
function Economy.JobQuote(run, memberId, jobId)
    if type(run) ~= "table" or type(run.members) ~= "table" then return nil, "当前家族数据无效。" end
    local sourceMember = State.FindMember(run.members, memberId)
    local job = Data.Jobs[jobId]
    if not sourceMember then return nil, "族人不存在。" end
    if not sourceMember.alive then return nil, "已故族人不能报价。" end
    if not job then return nil, "岗位不存在。" end
    local copy = State.Copy(run)
    local member = State.FindMember(copy.members, memberId)
    member.jobId = jobId
    local period = Data.Period(copy.eraId) or Data.Period("peace")
    local place = Data.Place(copy.placeId)
    if not place then return nil, "当前落脚处无效。" end
    local beforeMoney, beforeGrain = copy.money, copy.grain
    local applied = ApplyIncome(copy, member, job, period, place)
    local growth = applied.growth
    local growthText = "无属性成长"
    if growth.stat == "health" then
        growthText = "体魄 +" .. tostring(growth.health or 0)
    elseif growth.stat then
        growthText = assert(Data.FocusNames[growth.stat], "成长属性未登记") .. " +" .. tostring(growth.amount or 0)
    end
    return {
        baseMoney = job.money or 0,
        money = copy.money - beforeMoney,
        grain = copy.grain - beforeGrain,
        growth = growth,
        growthStat = growth.stat,
        growthText = growthText,
    }
end

-- 购粮与年度缺粮补购使用同一份时期和地点价格，界面预览可直接引用。
function Economy.GrainPurchasePrice(run, amount)
    amount = math.tointeger(amount)
    if not amount or amount <= 0 then return nil, "购粮数量须为正整数。" end
    local period = Data.Period(run.eraId) or Data.Period("peace")
    local place = Data.Place(run.placeId)
    if not place then return nil, "当前落脚处无效。" end
    return math.ceil(period.food * amount * (place.foodMultiplier or 1))
end

local function ResolveLivingCosts(run, living, period, place)
    local ledger = { foodCost = 0, boughtGrain = 0, grainSold = 0, saleIncome = 0 }
    local home = Data.Home(run.homeId)
    local baseExpense, carers = home.upkeep, 0
    for _, member in ipairs(living) do
        baseExpense = baseExpense + (State.IsAdult(member) and 4 or 2)
        if member.jobId == "home" then carers = carers + 1 end
    end
    local expense = math.floor(baseExpense * period.expense * (place.expenseMultiplier or 1))
    expense = math.max(0, expense - carers * 3)
    if run.habitId == "frugal" then expense = math.floor(expense * 0.9) end
    ledger.livingExpense = expense
    run.money = run.money - expense
    local foodNeed = 0
    for _, member in ipairs(living) do foodNeed = foodNeed + (State.IsAdult(member) and 2 or 1) end
    ledger.foodNeed = foodNeed; ledger.foodShortfall = math.max(0, foodNeed - run.grain)
    ledger.foodSatisfied = run.grain >= foodNeed
    if ledger.foodSatisfied then run.grain = run.grain - foodNeed else
        local missing = foodNeed - run.grain; run.grain = 0
        local price = Economy.GrainPurchasePrice(run, missing)
        if run.money >= price then
            run.money = run.money - price
            ledger.foodSatisfied = true; ledger.foodCost = price; ledger.boughtGrain = missing
        else
            run.money = math.max(0, run.money)
            for _, member in ipairs(living) do member.health = math.max(0, member.health - 12) end
            State.AddLog(run, "口粮不足，全家体魄各减 12 点，度过了艰难的一年。")
        end
    end
    if run.money < 0 and run.grain > 0 then
        local sold = math.min(run.grain, math.ceil(-run.money / period.food))
        run.grain = run.grain - sold; run.money = run.money + sold * period.food
        ledger.grainSold = sold; ledger.saleIncome = sold * period.food
        State.AddLog(run, "卖出 " .. tostring(sold) .. " 石粮以补足日常开支。")
    end
    ledger.moneySatisfied = run.money >= 0 and ledger.foodSatisfied
    run.metrics.foodYears = ledger.foodSatisfied and run.metrics.foodYears + 1 or 0
    run.metrics.stable = ledger.moneySatisfied and run.metrics.stable + 1 or 0
    return ledger
end

function Economy.Settle(run)
    local living = {}
    for _, member in ipairs(run.members) do if member.alive then table.insert(living, member) end end
    local period, place = Data.Period(run.eraId) or Data.Period("peace"), Data.Place(run.placeId)
    local beforeMoney, beforeGrain, rows = run.money, run.grain, {}
    local income, training = 0, 0
    for _, member in ipairs(living) do
        local job = Data.Jobs[member.jobId]
        local money, grain = run.money, run.grain
        ApplyIncome(run, member, job, period, place)
        local delta = run.money - money
        income = income + math.max(0, delta); training = training + math.max(0, -delta)
        table.insert(rows, { memberId = member.id, name = member.name, job = job.name, money = delta, grain = run.grain - grain })
        member.jobYears[member.jobId] = (member.jobYears[member.jobId] or 0) + 1
        if member.jobId == "official" then run.reputation = run.reputation + 1 end

    end
    if run.originId == "gentry" then run.reputation = run.reputation + 1 end
    local industryStart = run.money
    run.grain = run.grain + run.land * 4
    if run.workshop then
        local hasCraft = false; for _, member in ipairs(living) do if member.jobId == "craft" then hasCraft = true end end
        if hasCraft then run.money = run.money + 8 else State.AddLog(run, "作坊无人经营，今年没有额外收益。") end
    end
    if run.shop then
        local hasTrade = false; for _, member in ipairs(living) do if member.jobId == "trade" then hasTrade = true end end
        if hasTrade then run.money = run.money + 10 else State.AddLog(run, "商铺无人经营，今年没有额外收益。") end
    end
    if HasRelic(run, "plan") then
        local hasCraft = false
        for _, member in ipairs(living) do if member.jobId == "craft" then hasCraft = true end end
        if hasCraft then run.money = run.money + 5 end
    end
    local industryIncome = run.money - industryStart
    local ledger = ResolveLivingCosts(run, living, period, place)
    ledger.members = rows; ledger.income = income; ledger.training = training
    ledger.industryIncome = industryIncome; ledger.landGrain = run.land * 4
    ledger.beforeMoney = beforeMoney; ledger.beforeGrain = beforeGrain
    ledger.money = run.money; ledger.grain = run.grain
    ledger.netMoney = run.money - beforeMoney; ledger.netGrain = run.grain - beforeGrain
    ledger.resourcesExhausted = run.money == 0 and run.grain == 0
    return ledger
end

function Economy.Preview(run)
    return Economy.Settle(State.Copy(run))
end

return Economy
