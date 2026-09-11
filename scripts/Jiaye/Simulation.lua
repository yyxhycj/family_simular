local Data = require "Jiaye.Data"
local State = require "Jiaye.State"

local Simulation = {}

local function IsClosed(run)
    if run.ending then return true, "本局已落笔，只能回顾家史。" end
    return false, ""
end

local function Living(run)
    local result = {}
    for _, member in ipairs(run.members) do if member.alive then table.insert(result, member) end end
    return result
end

local function RelicInstance(run, instanceId)
    for _, relic in ipairs(run.relicInstances) do if relic.instanceId == instanceId then return relic end end
    return nil
end

local function HasRelic(run, relicId)
    for _, instance in ipairs(run.relicInstances) do
        if instance.definitionId == relicId and instance.status ~= "sold" then return instance end
    end
    return nil
end

local function JobYears(run, jobId)
    local total = 0
    for _, member in ipairs(run.members) do total = total + (member.jobYears[jobId] or 0) end
    return total
end

local function JobGenerations(run, jobId, years)
    local generations = {}
    for _, member in ipairs(run.members) do
        if (member.jobYears[jobId] or 0) >= years then
            local generation = #member.parents > 0 and 2 or 1
            generations[generation] = true
        end
    end
    local count = 0
    for _ in pairs(generations) do count = count + 1 end
    return count
end

local function EffectiveHandovers(run)
    local total = 0
    for _, term in ipairs(run.leaderTerms) do if term.effective then total = total + 1 end end
    return total
end

local function CurrentPlace(run) return Data.Place(run.placeId) end
local function CurrentPeriod(run) return Data.Period(run.eraId) or Data.Period("peace") end

local function AddEvent(run, event)
    event.instanceId = "event-" .. tostring(run.calendar) .. "-" .. tostring(#run.events + 1)
    event.status = "pending"
    table.insert(run.events, event)
    State.AddLog(run, event.title .. "：需要你的决定。")
    return event
end

function Simulation.PendingEvents(run)
    local pending = {}
    for _, event in ipairs(run.events) do if event.status == "pending" then table.insert(pending, event) end end
    return pending
end

local function QueueDueRelicEvents(run)
    for _, instance in ipairs(run.relicInstances) do
        if instance.status == "investigating" and instance.dueYear <= run.yearIndex then
            instance.status = "awaiting_resolution"
            AddEvent(run, { type = "relic_resolution", relicInstanceId = instance.instanceId, title = Data.Relic(instance.definitionId).name .. "有了新的线索", blocking = true })
        end
    end
end

function Simulation.GetJobReason(member, jobId)
    return State.CanUseJob(member, jobId)
end

function Simulation.SetJob(run, memberId, jobId)
    if run.ending then return false, "本局已落笔，只能回顾家史。" end
    local member = State.FindMember(run.members, memberId)
    if not member or not member.alive then return false, "这位族人已无法安排。" end
    local ok, reason = State.CanUseJob(member, jobId)
    if not ok then return false, reason end
    member.jobId = jobId
    State.AddLog(run, member.name .. "改为“" .. Data.Jobs[jobId].name .. "”。")
    return true, "安排已保存。"
end

function Simulation.TakeExam(run, memberId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local member = State.FindMember(run.members, memberId)
    if not member or not member.alive or member.age < 18 then return false, "只有在世成年族人可以应试。" end
    if member.examYear == run.yearIndex then return false, "此人今年已经应试。" end
    if run.money < 10 then return false, "应试需要 10 两盘缠。" end
    member.examYear = run.yearIndex; run.money = run.money - 10
    local score = (member.stats.learn or 0) + State.Random(run, 1, 40)
    if score >= 75 then member.examPassed = true; State.AddLog(run, member.name .. "应试得中，取得地方任职资格。") return true, "应试通过。" end
    State.AddLog(run, member.name .. "此次应试未中，仍可继续读书后再试。")
    return true, "此次未中，盘缠已计入年鉴。"
end

function Simulation.AppointLeader(run, memberId, reason)
    if run.ending then return false, "本局已落笔。" end
    local target = State.FindMember(run.members, memberId)
    if not target or not target.alive or target.age < 18 then return false, "族长必须是在世成年族人。" end
    if run.leaderId == memberId then return false, "此人已是族长。" end
    local old = State.FindMember(run.members, run.leaderId)
    for _, term in ipairs(run.leaderTerms) do if term.memberId == run.leaderId and not term.endYear then term.endYear = run.yearIndex end end
    local effective = old and target.age < old.age and run.yearIndex > 0 or false
    table.insert(run.leaderTerms, { memberId = memberId, startYear = run.yearIndex, endYear = nil, effective = effective, reason = reason or "主动交接" })
    run.leaderId = memberId
    State.AddLog(run, (old and old.name or "前任") .. "将族长之位交给了" .. target.name .. "。")
    return true, "族长已更替，其他族人的安排保持不变。"
end

function Simulation.Marry(run, memberId)
    if run.ending then return false, "本局已落笔。" end
    local member = State.FindMember(run.members, memberId)
    if not member or not member.alive or member.age < 18 then return false, "需要一位在世成年族人。" end
    if member.spouseId then return false, "此人已有配偶。" end
    if run.money < 12 then return false, "婚配需要 12 两安置费用。" end
    local spouseId = 1
    for _, item in ipairs(run.members) do if item.id >= spouseId then spouseId = item.id + 1 end end
    local spouse = { id = spouseId, name = (member.sex == "男" and "沈" or "顾") .. "新", sex = member.sex == "男" and "女" or "男", age = math.max(18, member.age - State.Random(run, 0, 5)), parents = {}, spouseId = member.id, talent = 2, focus = "general", experienceId = "basic", trait = "安稳", jobId = "home", alive = true, health = 72, stats = State.Copy(Data.Experience("basic").values), jobYears = {}, biography = { "因婚配加入“" .. run.openingSnapshot.family .. "”家。" }, fertility = true }
    member.spouseId = spouseId; member.fertility = true; run.money = run.money - 12
    table.insert(run.members, spouse)
    State.AddLog(run, member.name .. "与" .. spouse.name .. "成婚，新成员入谱。")
    return true, "婚配已写入家谱。"
end

function Simulation.Adopt(run, guardianId)
    if run.ending then return false, "本局已落笔。" end
    local guardian = State.FindMember(run.members, guardianId)
    if not guardian or not guardian.alive or guardian.age < 18 then return false, "需要一位在世成年监护人。" end
    if run.money < 8 then return false, "收养安置需要 8 两。" end
    local childId = 1
    for _, item in ipairs(run.members) do if item.id >= childId then childId = item.id + 1 end end
    local child = { id = childId, name = run.openingSnapshot.family .. "小满", sex = State.Random(run, 0, 1) == 0 and "女" or "男", age = 6, parents = { guardian.id }, spouseId = nil, talent = 2, focus = "general", experienceId = "none", trait = "敏锐", jobId = "study", alive = true, health = 70, stats = State.Copy(Data.Experience("none").values), jobYears = {}, biography = { "大晟历 " .. tostring(run.calendar) .. " 年被收养，监护人为" .. guardian.name .. "。" }, adopted = true }
    run.money = run.money - 8; table.insert(run.members, child)
    State.AddLog(run, guardian.name .. "收养了" .. child.name .. "，孩子获得与其他族人同等的成长和继任资格。")
    return true, "收养已完成。"
end

function Simulation.MoveFamily(run, placeId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local place = Data.Place(placeId)
    if not place then return false, "目的地不存在。" end
    if run.placeId == placeId then return false, "家族已经在这里。" end
    local fee = 18 + place.cost * 2
    if run.money < fee then return false, "迁居需要 " .. tostring(fee) .. " 两安置费。" end
    run.money = run.money - fee; run.placeId = placeId; run.metrics.migrations = run.metrics.migrations + 1; run.metrics.lastMove = run.yearIndex
    State.AddLog(run, "全家迁居至" .. place.short .. "，花费 " .. tostring(fee) .. " 两。")
    return true, "迁居已记入家史。"
end

function Simulation.BuyAsset(run, assetId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local prices = { land = 30, workshop = 80, shop = 120 }
    local price = prices[assetId]
    if not price then return false, "未知置办项目。" end
    if run.money < price then return false, "公库不足，需要 " .. tostring(price) .. " 两。" end
    if assetId == "workshop" and run.workshop then return false, "家中已有作坊。" end
    if assetId == "shop" and run.shop then return false, "家中已有商铺。" end
    run.money = run.money - price
    if assetId == "land" then run.land = run.land + 1 elseif assetId == "workshop" then run.workshop = true else run.shop = true end
    State.AddLog(run, "置办“" .. ({ land = "田地", workshop = "木工作坊", shop = "小商铺" })[assetId] .. "”，花费 " .. tostring(price) .. " 两。")
    return true, "置办完成。"
end

function Simulation.SellRelic(run, instanceId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local relic = RelicInstance(run, instanceId)
    if not relic or relic.status == "sold" then return false, "此物件已不在家中。" end
    local definition = Data.Relic(relic.definitionId)
    relic.status = "sold"; relic.stage = "closed"; run.money = run.money + definition.cost * 5
    for _, event in ipairs(run.events) do if event.relicInstanceId == relic.instanceId and event.status == "pending" then event.status = "cancelled" end end
    State.AddLog(run, "出售“" .. definition.name .. "”，未完成的调查已经停止；解锁资格和历史仍被保留。")
    return true, "物件已出售，未完后续不会再结算。"
end

function Simulation.StartRelicInvestigation(run, instanceId, route)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local instance = RelicInstance(run, instanceId)
    if not instance or instance.status == "sold" then return false, "此物件不在家中。" end
    if instance.status == "investigating" then return false, "调查已经在进行。" end
    if instance.status == "awaiting_resolution" then return false, "线索已到，请先处理结果。" end
    local definition = Data.Relic(instance.definitionId)
    local cost, years = route == "slow" and 4 or 8, route == "slow" and 2 or 1
    if route == "pause" then instance.stage = "paused"; State.AddLog(run, definition.name .. "的调查暂缓，可随时继续。") return true, "调查已暂缓。" end
    if run.money < cost then return false, "调查需要 " .. tostring(cost) .. " 两。" end
    run.money = run.money - cost; instance.status = "investigating"; instance.stage = route; instance.dueYear = run.yearIndex + years
    State.AddLog(run, "为“" .. definition.name .. "”安排" .. (route == "slow" and "慢查" or "查访") .. "，花费 " .. tostring(cost) .. " 两，约 " .. tostring(years) .. " 年后有消息。")
    return true, "调查已安排，主业不会被改动。"
end

function Simulation.ResolveEvent(run, eventId, choice, profile)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local event = nil
    for _, item in ipairs(run.events) do if item.instanceId == eventId then event = item end end
    if not event or event.status ~= "pending" then return false, "这件事已处理或不存在。" end
    if event.type ~= "relic_resolution" then event.status = "resolved" return true, "事件已记录。" end
    local instance = RelicInstance(run, event.relicInstanceId)
    if not instance or instance.status == "sold" then event.status = "cancelled" return false, "物件已出售，后续不会结算。" end
    local relic = Data.Relic(instance.definitionId)
    event.status = "resolved"; instance.status = "held"; instance.stage = "completed"
    if choice == "restore" then
        if relic.unlock then profile.unlockedRelicIds[relic.unlock] = true end
        if relic.id == "ruler" then run.flags.rulerRestored = true elseif relic.id == "book" then run.flags.bookRestored = true elseif relic.id == "letter" then run.flags.promiseKept = true end
        State.AddLog(run, "你修复并安置了“" .. relic.name .. "”。" .. (relic.unlock and "新局已解锁“" .. Data.Relic(relic.unlock).name .. "”资格。" or "这段家史被完整记下。"))
        return true, "结果已写入家史与收藏。"
    end
    State.AddLog(run, "“" .. relic.name .. "”的线索被妥善保存，暂不继续修复。")
    return true, "后续被保留在家史中。"
end

local function ApplyIncome(run, member, job, period, place)
    local money, grain = job.money or 0, job.grain or 0
    money = math.floor(money * period.wage)
    if member.jobId == "craft" and place.id == "mountain" then money = math.floor(money * 1.1) end
    if member.jobId == "doctor" and place.id == "mountain" then money = math.floor(money * 1.1) end
    if member.jobId == "guard" and place.id == "border" then money = math.floor(money * 1.2) end
    if member.jobId == "trade" and place.id == "port" then money = math.floor(money * 1.2) end
    if member.jobId == "trade" and run.originId == "merchant" then money = math.floor(money * 1.1) end
    if member.jobId == "guard" and run.originId == "military" then money = math.floor(money * 1.1) end
    if member.jobId == "trade" and run.tieId == "partner" then money = money + 3 end
    if member.jobId == "teach" and run.tieId == "teacher" then money = money + 2 end
    if member.jobId == "farm" then grain = grain + run.land * 2 + (place.id == "village" and 2 or 0) + (run.originId == "plain" and 1 or 0) end
    run.money = run.money + money; run.grain = run.grain + grain
    if job.stat == "health" then
        member.health = math.min(100, member.health + math.max(0, job.gain or 0))
    elseif job.stat then
        local talent = Data.Talent(math.tointeger(member.talent) or 1)
        local gain = (job.gain or 0) + talent.gain
        if run.habitId == "education" and member.jobId == "study" then gain = gain + 1 end
        if run.tieId == "healer" and member.jobId == "medical" then gain = gain + 1 end
        if run.originId == "artisan" and (member.jobId == "apprentice" or member.jobId == "craft") then gain = gain + 1 end
        if run.originId == "scholar" and member.jobId == "study" then gain = gain + 2 end
        if run.originId == "military" and member.jobId == "train" then gain = gain + 2 end
        member.stats[job.stat] = math.min(100, (member.stats[job.stat] or 0) + math.max(0, gain))
    end
    if member.jobId == "home" then member.health = math.min(100, member.health + 1) end
    if member.jobId == "rest" then member.health = math.min(100, member.health + (run.homeId == "estate" and 2 or run.homeId == "courtyard" and 1 or 0)) end
end

local function ResolveLivingCosts(run, living, period, place)
    local home = Data.Home(run.homeId)
    local expense = math.floor((#living * 2 + home.upkeep) * period.expense * (place.id == "border" or place.id == "county" or place.id == "port" and 1.05 or 1))
    for _, member in ipairs(living) do if member.jobId == "home" then expense = math.max(0, expense - 3); break end end
    if run.habitId == "frugal" then expense = math.floor(expense * 0.9) end
    run.money = run.money - expense
    local foodNeed = #living
    if run.grain >= foodNeed then run.grain = run.grain - foodNeed; run.metrics.foodYears = run.metrics.foodYears + 1 else
        local missing = foodNeed - run.grain; run.grain = 0
        local price = period.food * missing
        if run.money >= price then run.money = run.money - price; run.metrics.foodYears = run.metrics.foodYears + 1 else run.money = math.max(0, run.money); State.AddLog(run, "口粮不足，家中度过了艰难的一年。") end
    end
    if run.money < 0 and run.grain > 0 then
        local sold = math.min(run.grain, math.ceil(-run.money / period.food))
        run.grain = run.grain - sold; run.money = run.money + sold * period.food
        State.AddLog(run, "卖出 " .. tostring(sold) .. " 石粮以补足日常开支。")
    end
    if run.money >= 0 then run.metrics.stable = run.metrics.stable + 1 else run.metrics.stable = 0 end
end

local function AgeAndLife(run, living)
    for _, member in ipairs(living) do
        member.age = member.age + 1
        local danger = member.age >= 82 and (member.age - 80) * 0.04 or (member.age >= 68 and (member.age - 67) * 0.008 or 0)
        if member.health < 20 then danger = danger + 0.05 end
        if State.Random(run) < danger then
            member.alive = false
            for _, relic in ipairs(run.relicInstances) do if relic.custodianId == member.id and relic.status ~= "sold" then relic.custodianId = run.leaderId end end
            State.AddLog(run, member.name .. "于大晟历 " .. tostring(run.calendar) .. " 年离世，生平被保留在家谱中。")
        end
    end
end

local function HandleLeadership(run)
    local leader = State.FindMember(run.members, run.leaderId)
    if leader and leader.alive then return end
    local candidates = {}
    for _, member in ipairs(run.members) do if member.alive and member.age >= 18 then table.insert(candidates, member) end end
    if #candidates > 0 then AddEvent(run, { type = "leader", title = "族长之位空缺", blocking = true }) else State.AddLog(run, "家中暂时只剩未成年人，由乡里代为照应，待成年后再定族长。") end
end

function Simulation.AdvanceYear(run, profile)
    if run.ending then return false, "本局已落笔，不能再推进。" end
    if #Simulation.PendingEvents(run) > 0 then return false, "请先处理待决事件。" end
    local living = Living(run)
    if #living == 0 then return false, "家谱已经落笔。" end
    local period, place = CurrentPeriod(run), CurrentPlace(run)
    for _, member in ipairs(living) do
        local job = Data.Jobs[member.jobId]
        ApplyIncome(run, member, job, period, place)
        member.jobYears[member.jobId] = (member.jobYears[member.jobId] or 0) + 1
        if member.jobId == "official" then run.reputation = run.reputation + 1 end
        if run.originId == "gentry" then run.reputation = run.reputation + 1 end
    end
    if run.workshop then
        local hasCraft = false; for _, member in ipairs(living) do if member.jobId == "craft" then hasCraft = true end end
        if hasCraft then run.money = run.money + 12 else State.AddLog(run, "作坊无人经营，今年没有额外收益。") end
    end
    if run.shop then
        local hasTrade = false; for _, member in ipairs(living) do if member.jobId == "trade" then hasTrade = true end end
        if hasTrade then run.money = run.money + 16 else State.AddLog(run, "商铺无人经营，今年没有额外收益。") end
    end
    ResolveLivingCosts(run, living, period, place)
    run.yearIndex = run.yearIndex + 1; run.calendar = run.calendar + 1
    AgeAndLife(run, living); QueueDueRelicEvents(run); HandleLeadership(run)
    if not HasRelic(run, "notes") then
        for _, member in ipairs(run.members) do if member.alive and (member.jobYears.doctor or 0) >= 4 and (member.stats.medicine or 0) >= 55 then profile.unlockedRelicIds.notes = true end end
    end
    if #Living(run) == 0 then
        run.ending = { id = "last", title = "家谱落笔", automatic = true, year = run.calendar, summary = "直到最后一位家人离开，这一局自然写到结尾。" }
        State.AddLog(run, "全员离世，家谱自然落笔。")
    else
        State.AddLog(run, "大晟历 " .. tostring(run.calendar) .. " 年结算完成。")
    end
    run.revision = run.revision + 1
    return true, "一年过去了。"
end

function Simulation.ResolveLeaderEvent(run, eventId, memberId)
    local event = nil; for _, item in ipairs(run.events) do if item.instanceId == eventId then event = item end end
    if not event or event.type ~= "leader" or event.status ~= "pending" then return false, "继任事件已失效。" end
    local ok, message = Simulation.AppointLeader(run, memberId, "前任离世")
    if ok then event.status = "resolved" end
    return ok, message
end

function Simulation.AidCommunity(run)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    if run.money < 15 then return false, "接济邻里需要 15 两。" end
    run.money = run.money - 15; run.reputation = run.reputation + 12; run.metrics.aid = run.metrics.aid + 1
    State.AddLog(run, "家中接济了邻里，声望提升。")
    return true, "援助已被记入家史。"
end

function Simulation.EndingProgress(run, endingId)
    local progress = {
        peaceful = { { "实际经营十年", run.yearIndex, 10 }, { "连续五年生活充足", run.metrics.stable, 5 }, { "真实交接", EffectiveHandovers(run), 1 } },
        scholar = { { "两代教书", JobGenerations(run, "teach", 2), 2 }, { "积蓄", run.money, 200 }, { "真实交接", EffectiveHandovers(run), 1 } },
        merchant = { { "两代经商", JobGenerations(run, "trade", 3), 2 }, { "积蓄", run.money, 300 }, { "真实交接", EffectiveHandovers(run), 1 } },
        craft = { { "两代手艺", JobGenerations(run, "craft", 3), 2 }, { "作坊有人经营", run.workshop and JobYears(run, "craft") > 0 and 1 or 0, 1 }, { "真实交接", EffectiveHandovers(run), 1 } },
        medical = { { "两代行医", JobGenerations(run, "doctor", 2), 2 }, { "行医人年", JobYears(run, "doctor"), 12 }, { "真实交接", EffectiveHandovers(run), 1 } },
        grain = { { "实际经营", run.yearIndex, 15 }, { "连续生活充足", run.metrics.foodYears, 10 }, { "存粮", run.grain, 80 } },
        community = { { "实际经营", run.yearIndex, 12 }, { "援助邻里", run.metrics.aid, 3 }, { "声望", run.reputation, 70 } },
        migration = { { "实际迁居", run.metrics.migrations, 1 }, { "迁居后年数", run.yearIndex - run.metrics.lastMove, 8 }, { "连续生活充足", run.metrics.stable, 5 } },
        ["return"] = { { "护卫后返家", (function() for _, m in ipairs(Living(run)) do if (m.jobYears.guard or 0) >= 3 and (m.jobId == "rest" or m.jobId == "farm" or m.jobId == "home") then return 1 end end return 0 end)(), 1 }, { "实际经营", run.yearIndex, 8 }, { "真实交接", EffectiveHandovers(run), 1 } },
        promise = { { "完成旧约", run.flags.promiseKept and 1 or 0, 1 }, { "实际经营", run.yearIndex, 6 }, { "连续生活充足", run.metrics.stable, 3 } },
        ruler = { { "修复旧尺", run.flags.rulerRestored and 1 or 0, 1 }, { "手艺人年", JobYears(run, "craft"), 8 }, { "真实交接", EffectiveHandovers(run), 1 } },
        reunion = { { "重修族谱", run.flags.bookRestored and 1 or 0, 1 }, { "实际经营", run.yearIndex, 6 }, { "真实交接", EffectiveHandovers(run), 1 } },
    }
    return progress[endingId] or {}
end

function Simulation.AvailableEndings(run)
    local ready = {}
    for _, ending in ipairs(Data.Endings) do
        local ok = true
        for _, item in ipairs(Simulation.EndingProgress(run, ending.id)) do if item[2] < item[3] then ok = false end end
        if ok then table.insert(ready, ending) end
    end
    return ready
end

function Simulation.ClaimEnding(run, endingId, profile)
    if run.ending then return false, "本局已经有主终章。" end
    local ending = Data.Ending(endingId)
    if not ending then return false, "终章不存在。" end
    local ready = false; for _, item in ipairs(Simulation.AvailableEndings(run)) do if item.id == endingId then ready = true end end
    if not ready then return false, "条件尚未满足。" end
    run.ending = { id = ending.id, title = ending.title, year = run.calendar, summary = ending.desc, yearIndex = run.yearIndex, leaderId = run.leaderId, evidence = Simulation.EndingProgress(run, endingId) }
    table.insert(profile.endingRecords, State.Copy(run.ending)); State.AddLog(run, "选择“" .. ending.title .. "”作为这一局的主终章。")
    return true, "家业已落笔；人物与家史仍可回顾。"
end

return Simulation
