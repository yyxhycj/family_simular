local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Habits = require "Jiaye.Habits"
local RelicState = require "Jiaye.RelicState"
local OriginEffects = require "Jiaye.OriginEffects"

local Economy = {}

local function IsV12(run)
    return type(run) == "table" and run.relicRulesVersion == "1.2"
end

local function List(value)
    return type(value) == "table" and value or {}
end

local function Living(run)
    local result = {}
    for _, member in ipairs(List(run.members)) do
        if member.alive ~= false then table.insert(result, member) end
    end
    return result
end

local function HasRelic(run, id)
    for _, item in ipairs(List(run.relicInstances)) do
        if item.definitionId == id and item.status ~= "sold" then return true end
    end
    return false
end

local function EffectiveJobMoney(run, member, job, period, place)
    local money = math.floor((job.money or 0) * period.wage)
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
    return money
end

local function JobGrain(run, member, place)
    local grain = (Data.Jobs[member.jobId].grain or 0)
    if member.jobId == "farm" then
        grain = grain + (place.id == "village" and 2 or 0) + (place.farmGrainModifier or 0) + (run.originId == "plain" and 1 or 0)
    end
    return grain
end

local function GrowthText(growth)
    if growth.stat == "health" then return "体魄 +" .. tostring(growth.health or 0) end
    if growth.stat then return assert(Data.FocusNames[growth.stat], "成长属性未登记") .. " +" .. tostring(growth.amount or 0) end
    return "无属性成长"
end

local function CurrentYearOriginTransactions(run, year)
    local rows = {}
    for _, entry in ipairs(List(run.originTransactions)) do
        if entry.yearIndex == year then table.insert(rows, State.Copy(entry)) end
    end
    return rows
end

local function BaseGrowth(run, member, job, place)
    if not job.stat then return nil, 0 end
    local talent = Data.Talent(math.tointeger(member.talent) or 1)
    local gain = (job.gain or 0) + talent.gain
    if place.id == "county" and member.jobId == "study" then gain = gain + 1 end
    if run.tieId == "teacher" and member.jobId == "study" then gain = gain + 1 end
    if run.tieId == "healer" and member.jobId == "medical" then gain = gain + 1 end
    if run.originId == "artisan" and (member.jobId == "apprentice" or member.jobId == "craft") then gain = gain + 1 end
    if run.originId == "scholar" and member.jobId == "study" then gain = gain + 2 end
    if run.originId == "military" and member.jobId == "train" then gain = gain + 2 end
    return job.stat, gain
end

local function ApplyGrowth(run, member, job, place, effects, origin)
    origin = origin or { learn = 0 }
    local growth = { stat = job.stat, amount = 0, health = 0, gain = 0, baseGrowth = 0, relicGrowth = 0, habitGrowth = 0, originGrowth = 0 }
    local initialHealth = member.health
    if job.stat == "health" then
        local before = member.health
        member.health = math.min(100, member.health + math.max(0, job.gain or 0))
        growth.health = member.health - before
    end
    if job.stat and job.stat ~= "health" then
        local stat, gain = BaseGrowth(run, member, job, place)
        local baseGain = gain
        local relicGain = (stat == "skill" and effects.skill or 0) + (stat == "medicine" and effects.medicine or 0)
        local habitGain = member.jobId == "study" and Habits.Growth(run, member) or 0
        local originGain = stat == "learn" and (origin.learn or 0) or 0
        gain = gain + relicGain + habitGain + originGain
        local before = member.stats[stat] or 0
        member.stats[stat] = math.min(100, before + math.max(0, gain))
        growth.amount = member.stats[stat] - before
        growth.gain = gain
        growth.baseGrowth = baseGain
        growth.relicGrowth = relicGain
        growth.habitGrowth = habitGain
        growth.originGrowth = originGain
    end
    if member.jobId == "home" then
        local before = member.health
        member.health = math.min(100, member.health + 1)
        growth.stat = "health"; growth.health = member.health - before
    elseif member.jobId == "rest" then
        local recovery = (run.homeId == "estate" and 2 or run.homeId == "courtyard" and 1 or 0) + (run.habitId == "care" and 2 or 0)
        member.health = math.min(100, member.health + recovery)
        growth.stat = "health"; growth.health = member.health - initialHealth; growth.gain = (job.gain or 0) + recovery
    end
    return growth
end

local function RelicSourceRows(effects)
    local rows = {}
    for familyId, source in pairs(effects.relicSources or {}) do
        local money = source.money or 0
        table.insert(rows, {
            familyId = familyId,
            instanceId = source.instanceId,
            formId = source.formId,
            skill = source.skill or 0,
            medicine = source.medicine or 0,
            money = money,
            category = money > 0 and "relic_passive_income" or "relic_growth",
        })
    end
    table.sort(rows, function(left, right) return tostring(left.familyId) < tostring(right.familyId) end)
    return rows
end

local function NewMemberRow(run, snapshot, period, place)
    local job = Data.Jobs[snapshot.jobId]
    local row = {
        memberId = snapshot.id, name = snapshot.name, jobId = snapshot.jobId,
        job = job and job.name or tostring(snapshot.jobId), money = 0, grain = 0,
        executed = false, paid = 0, growth = { stat = job and job.stat, amount = 0, health = 0, gain = 0 },
        baseGrowth = 0, relicGrowth = 0, habitGrowth = 0, relicIncome = 0, relicSources = {}, reason = nil,
        originGrowth = 0, originIncome = 0, originSources = {},
    }
    if not job then row.reason = "岗位定义不存在，年度安排未执行。"; return row end
    local eligible, eligibilityReason = State.CanUseJob(snapshot, snapshot.jobId)
    if not eligible then row.reason = eligibilityReason .. "本年度未执行。"; return row end
    local effects = RelicState.EffectsFor(run, snapshot)
    row.relicSources = RelicSourceRows(effects)
    local effectiveMoney = EffectiveJobMoney(run, snapshot, job, period, place)
    local payment = math.max(0, -effectiveMoney)
    if payment > 0 and run.money < payment then
        row.reason = "现银不足，无法支付本年度 " .. tostring(payment) .. " 两培养费；未扣款、未计训练。"
        return row
    end
    local member = State.FindMember(run.members, snapshot.id)
    if not member then row.reason = "成员已不在当前家谱中，年度安排未执行。"; return row end
    if payment > 0 then run.money = run.money - payment; row.paid = payment end
    if effectiveMoney > 0 then run.money = run.money + effectiveMoney end
    local grain = JobGrain(run, snapshot, place)
    run.grain = run.grain + grain
    local origin = OriginEffects.ForMember(run, snapshot, (run.yearIndex or 0) + 1)
    if origin.money ~= 0 then run.money = run.money + origin.money end
    row.money = effectiveMoney + effects.money + origin.money
    row.relicIncome = effects.money
    row.originIncome = origin.money
    row.originSources = origin.sources
    if effects.money > 0 then run.money = run.money + effects.money end
    row.grain = grain
    row.executed = true
    row.growth = ApplyGrowth(run, member, job, place, effects, origin)
    row.baseGrowth = row.growth.baseGrowth or 0
    row.relicGrowth = row.growth.relicGrowth or 0
    row.habitGrowth = row.growth.habitGrowth or 0
    row.originGrowth = row.growth.originGrowth or 0
    member.jobYears = member.jobYears or {}
    member.jobYears[snapshot.jobId] = (member.jobYears[snapshot.jobId] or 0) + 1
    return row
end

local function ApplyLegacyIncome(run, member, job, period, place)
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

local function StandardAnnualFoodNeedFor(run, living)
    local need = 0
    for _, member in ipairs(living or Living(run)) do need = need + (State.IsAdult(member) and 2 or 1) end
    return need
end

function Economy.StandardAnnualFoodNeed(run)
    return StandardAnnualFoodNeedFor(run, Living(run))
end

local function GrainPurchasePrice(run, amount)
    amount = math.tointeger(amount)
    if not amount or amount <= 0 then return nil, "购粮数量须为正整数。" end
    local period = Data.Period(run.eraId) or Data.Period("peace")
    local place = Data.Place(run.placeId)
    if not place then return nil, "当前落脚处无效。" end
    return math.ceil(period.food * amount * (place.foodMultiplier or 1))
end

function Economy.GrainPurchasePrice(run, amount)
    return GrainPurchasePrice(run, amount)
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
    local foodNeed = StandardAnnualFoodNeedFor(run, living)
    ledger.foodNeed = foodNeed; ledger.foodShortfall = math.max(0, foodNeed - run.grain)
    ledger.foodSatisfied = run.grain >= foodNeed
    if ledger.foodSatisfied then run.grain = run.grain - foodNeed else
        local missing = foodNeed - run.grain; run.grain = 0
        local price = GrainPurchasePrice(run, missing)
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

local function SettleLegacy(run)
    local living = Living(run)
    local period, place = Data.Period(run.eraId) or Data.Period("peace"), Data.Place(run.placeId)
    local beforeMoney, beforeGrain, rows = run.money, run.grain, {}
    local income, training = 0, 0
    for _, member in ipairs(living) do
        local job = Data.Jobs[member.jobId]
        local money, grain = run.money, run.grain
        ApplyLegacyIncome(run, member, job, period, place)
        local delta = run.money - money
        income = income + math.max(0, delta); training = training + math.max(0, -delta)
        table.insert(rows, { memberId = member.id, name = member.name, jobId = member.jobId, job = job.name, money = delta, grain = run.grain - grain, executed = true, paid = math.max(0, -delta), growth = State.Copy(member.stats), relicSources = {} })
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
    ledger.members = rows
    ledger.income = income
    ledger.training = training
    ledger.industryIncome = industryIncome
    ledger.landGrain = run.land * 4
    ledger.beforeMoney = beforeMoney
    ledger.beforeGrain = beforeGrain
    ledger.money = run.money
    ledger.grain = run.grain
    ledger.netMoney = run.money - beforeMoney
    ledger.netGrain = run.grain - beforeGrain
    ledger.resourcesExhausted = run.money == 0 and run.grain == 0
    return ledger
end

local function SettleV12(run)
    local living = Living(run)
    local period, place = Data.Period(run.eraId) or Data.Period("peace"), Data.Place(run.placeId)
    local beforeMoney, beforeGrain, rows = run.money, run.grain, {}
    local income, training, relicPassiveIncome, originIncome, originGrowth = 0, 0, 0, 0, 0
    local snapshots = {}
    for _, member in ipairs(living) do table.insert(snapshots, State.Copy(member)) end
    for _, snapshot in ipairs(snapshots) do
        local before = run.money
        local row = NewMemberRow(run, snapshot, period, place)
        table.insert(rows, row)
        if row.executed then
            local baseDelta = run.money - before - (row.relicIncome or 0) - (row.originIncome or 0)
            if baseDelta > 0 then income = income + baseDelta end
            training = training + row.paid
            originIncome = originIncome + (row.originIncome or 0)
            originGrowth = originGrowth + (row.originGrowth or 0)
            for _, source in ipairs(row.relicSources) do
                if source.category == "relic_passive_income" then relicPassiveIncome = relicPassiveIncome + source.money end
            end
            local member = State.FindMember(run.members, snapshot.id)
            if member and member.jobId == "official" then run.reputation = run.reputation + 1 end
        end
    end
    if run.originId == "gentry" then run.reputation = run.reputation + 1 end
    local industryStart = run.money
    run.grain = run.grain + run.land * 4
    local originGrain = OriginEffects.HouseholdGrain(run, rows, (run.yearIndex or 0) + 1)
    run.grain = run.grain + originGrain.grain
    if run.workshop then
        local hasCraft = false; for _, row in ipairs(rows) do if row.executed and row.jobId == "craft" then hasCraft = true end end
        if hasCraft then run.money = run.money + 8 else State.AddLog(run, "作坊无人经营，今年没有额外收益。") end
    end
    if run.shop then
        local hasTrade = false; for _, row in ipairs(rows) do if row.executed and row.jobId == "trade" then hasTrade = true end end
        if hasTrade then run.money = run.money + 10 else State.AddLog(run, "商铺无人经营，今年没有额外收益。") end
    end
    local industryIncome = run.money - industryStart
    local ledger = ResolveLivingCosts(run, living, period, place)
    ledger.members = rows
    ledger.income = income
    ledger.training = training
    ledger.industryIncome = industryIncome
    ledger.landGrain = run.land * 4
    ledger.relicIncome = relicPassiveIncome
    ledger.relicPassiveIncome = relicPassiveIncome
    ledger.originIncome = originIncome
    ledger.originGrowth = originGrowth
    ledger.originGrain = originGrain.grain
    ledger.originGrainSources = originGrain.sources
    ledger.originSources = {}
    ledger.relicSources = {}
    for _, row in ipairs(rows) do
        for _, source in ipairs(row.relicSources) do table.insert(ledger.relicSources, State.Copy(source)) end
        for _, source in ipairs(row.originSources) do table.insert(ledger.originSources, State.Copy(source)) end
    end
    ledger.originTransactions = CurrentYearOriginTransactions(run, (run.yearIndex or 0) + 1)
    ledger.beforeMoney = beforeMoney
    ledger.beforeGrain = beforeGrain
    ledger.money = run.money
    ledger.grain = run.grain
    ledger.netMoney = run.money - beforeMoney
    ledger.netGrain = run.grain - beforeGrain
    ledger.resourcesExhausted = run.money == 0 and run.grain == 0
    return ledger
end

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
    if not IsV12(run) then
        local beforeMoney, beforeGrain = copy.money, copy.grain
        local applied = ApplyLegacyIncome(copy, member, job, period, place)
        return { baseMoney = job.money or 0, money = copy.money - beforeMoney, grain = copy.grain - beforeGrain, growth = applied.growth, growthStat = applied.growth.stat, growthText = GrowthText(applied.growth), executed = true, paid = math.max(0, beforeMoney - copy.money) }
    end
    local ledger = SettleV12(copy)
    local row = nil
    for _, candidate in ipairs(ledger.members or {}) do
        if candidate.memberId == memberId then row = candidate; break end
    end
    if not row then return nil, "年度报价未生成对应成员记录。" end
    return { baseMoney = job.money or 0, money = row.money, grain = row.grain, originGrain = ledger.originGrain or 0, growth = row.growth, growthStat = row.growth.stat, growthText = row.executed and GrowthText(row.growth) or (row.reason or "本年度未执行"), executed = row.executed, paid = row.paid, reason = row.reason, relicSources = row.relicSources, originSources = row.originSources, originIncome = row.originIncome, originGrowth = row.originGrowth, baseGrowth = row.baseGrowth, relicGrowth = row.relicGrowth, habitGrowth = row.habitGrowth }
end

function Economy.Settle(run)
    if IsV12(run) then return SettleV12(run) end
    return SettleLegacy(run)
end

function Economy.Preview(run)
    local copy = State.Copy(run)
    if IsV12(copy) then return SettleV12(copy) end
    return SettleLegacy(copy)
end

function Economy.AnnualForecast(run)
    if type(run) ~= "table" then return nil, "当前家谱数据无效。" end
    local ledger = Economy.Preview(run)
    return {
        livingExpense = ledger.livingExpense or 0,
        foodNeed = ledger.foodNeed or Economy.StandardAnnualFoodNeed(run),
        foodShortfall = ledger.foodShortfall or 0,
        foodSatisfied = ledger.foodSatisfied == true,
        foodCost = ledger.foodCost or 0,
        boughtGrain = ledger.boughtGrain or 0,
        projectedGrain = ledger.grain or run.grain or 0,
        netGrain = ledger.netGrain or 0,
    }
end

Economy.RelicState = RelicState
Economy.OriginEffects = OriginEffects

return Economy
