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
            local generation = State.Generation(run.members, member.id)
            generations[generation] = true
        end
    end
    local count = 0
    for _ in pairs(generations) do count = count + 1 end
    return count
end

local function NextMemberId(run)
    local nextId = 1
    for _, member in ipairs(run.members) do if member.id >= nextId then nextId = member.id + 1 end end
    return nextId
end

local function AddRelicInstance(run, definitionId, custodianId)
    if HasRelic(run, definitionId) then return nil end
    local instance = {
        instanceId = "relic-" .. tostring(#run.relicInstances + 1) .. "-" .. definitionId,
        definitionId = definitionId, status = "held", custodianId = custodianId or run.leaderId, stage = "idle",
    }
    table.insert(run.relicInstances, instance)
    return instance
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
    if (member.jobYears.guard or 0) >= 3 and (jobId == "home" or jobId == "farm" or jobId == "rest") then member.hadHomeAfterGuard = true end
    member.jobId = jobId
    State.AddLog(run, member.name .. "改为“" .. Data.Jobs[jobId].name .. "”。")
    return true, "安排已保存。"
end

function Simulation.SetBirthPlan(run, memberId, enabled)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local member = State.FindMember(run.members, memberId)
    if not member or not member.alive or member.age < 18 then return false, "只有在世成年族人可以安排这件事。" end
    member.birthPlan = enabled
    State.AddLog(run, member.name .. (enabled and "愿意迎来孩子。" or "决定暂不计划生育。"))
    return true, enabled and "已记录生育计划。" or "已记录暂缓计划。"
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
    for _, term in ipairs(run.leaderTerms) do
        if term.memberId == run.leaderId and not term.endYear then
            term.endYear = run.yearIndex
            term.effective = run.yearIndex - term.startYear >= 1
        end
    end
    local effective = false
    table.insert(run.leaderTerms, { memberId = memberId, startYear = run.yearIndex, endYear = nil, effective = effective, reason = reason or "主动交接" })
    run.leaderId = memberId
    if HasRelic(run, "newbook") and old then
        run.reputation = run.reputation + 3
        State.AddLog(run, "补完的族谱为这次有效交接添了 3 点声望。")
    end
    State.AddLog(run, (old and old.name or "前任") .. "将族长之位交给了" .. target.name .. "。")
    return true, "族长已更替，其他族人的安排保持不变。"
end

function Simulation.Marry(run, memberId)
    if run.ending then return false, "本局已落笔。" end
    local member = State.FindMember(run.members, memberId)
    if not member or not member.alive or member.age < 18 then return false, "需要一位在世成年族人。" end
    if member.spouseId then return false, "此人已有配偶。" end
    if run.money < 12 then return false, "婚配需要 12 两安置费用。" end
    local spouseId = NextMemberId(run)
    local spouseSex = member.sex == "男" and "女" or "男"
    ---@type string[]
    local names = spouseSex == "男" and Data.GivenNames.male or Data.GivenNames.female
    local spouse = { id = spouseId, name = (spouseSex == "男" and "沈" or "顾") .. names[State.Random(run, 1, #names)], sex = spouseSex, age = math.max(18, member.age - State.Random(run, 0, 5)), parents = {}, spouseId = member.id, talent = 2, focus = "general", experienceId = "basic", trait = "安稳", jobId = "home", alive = true, health = 72, stats = State.Copy(Data.Experience("basic").values), jobYears = {}, biography = { "因婚配加入“" .. run.openingSnapshot.family .. "”家。" }, fertility = true, birthPlan = true, lastBirthYear = -5, hadHomeAfterGuard = false, generation = State.Generation(run.members, member.id) }
    member.spouseId = spouseId; member.fertility = true; member.birthPlan = true; run.money = run.money - 12
    table.insert(run.members, spouse)
    State.AddLog(run, member.name .. "与" .. spouse.name .. "成婚，新成员入谱。")
    return true, "婚配已写入家谱。"
end

function Simulation.Adopt(run, guardianId)
    if run.ending then return false, "本局已落笔。" end
    local guardian = State.FindMember(run.members, guardianId)
    if not guardian or not guardian.alive or guardian.age < 18 then return false, "需要一位在世成年监护人。" end
    if run.money < 8 then return false, "收养安置需要 8 两。" end
    local childId = NextMemberId(run)
    local child = { id = childId, name = run.openingSnapshot.family .. "小满", sex = State.Random(run, 0, 1) == 0 and "女" or "男", age = 6, parents = { guardian.id }, spouseId = nil, talent = 2, focus = "general", experienceId = "none", trait = "敏锐", jobId = "study", alive = true, health = 70, stats = State.Copy(Data.Experience("none").values), jobYears = {}, biography = { "大晟历 " .. tostring(run.calendar) .. " 年被收养，监护人为" .. guardian.name .. "。" }, adopted = true, birthPlan = true, lastBirthYear = -5, hadHomeAfterGuard = false, generation = State.Generation(run.members, guardian.id) + 1 }
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
    relic.status = "sold"; relic.stage = "closed"; run.money = run.money + (definition.saleValue or definition.cost * 2)
    for _, event in ipairs(run.events) do if event.relicInstanceId == relic.instanceId and event.status == "pending" then event.status = "cancelled" end end
    State.AddLog(run, "出售“" .. definition.name .. "”，未完成的调查已经停止；解锁资格和历史仍被保留。")
    return true, "物件已出售，未完后续不会再结算。"
end

function Simulation.TransferRelic(run, instanceId, memberId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local relic = RelicInstance(run, instanceId)
    local member = State.FindMember(run.members, memberId)
    if not relic or relic.status == "sold" then return false, "此物件已不在家中。" end
    if not member or not member.alive then return false, "只能托付给在世族人。" end
    relic.custodianId = member.id
    State.AddLog(run, "“" .. Data.Relic(relic.definitionId).name .. "”改由" .. member.name .. "保管。")
    return true, "保管人已更换。"
end

function Simulation.InviteBranch(run, instanceId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local relic = RelicInstance(run, instanceId)
    if not relic or relic.definitionId ~= "newbook" or relic.status == "sold" then return false, "需要家中实际持有“补完的族谱”。" end
    if run.flags.branchInvited then return false, "这支旁系已经归家。" end
    if run.money < 12 then return false, "安置成年旁支需要 12 两。" end
    local id = NextMemberId(run)
    local leader = State.FindMember(run.members, run.leaderId)
    local member = {
        id = id, name = run.openingSnapshot.family .. "怀远", sex = "男", age = 22, parents = {}, spouseId = nil,
        talent = 2, focus = "general", experienceId = "basic", trait = "念旧", jobId = "farm", alive = true, health = 72,
        stats = State.Copy(Data.Experience("basic").values), jobYears = {}, birthPlan = true, lastBirthYear = -5,
        hadHomeAfterGuard = false, generation = leader and leader.generation or 1,
        biography = { "因补完的族谱寻回旁支，于大晟历 " .. tostring(run.calendar) .. " 年归家。" }, branch = true,
    }
    run.money = run.money - 12; run.flags.branchInvited = true; table.insert(run.members, member)
    State.AddLog(run, member.name .. "作为成年旁支归家，名字被正式写回族谱。")
    return true, "成年旁支已归家。"
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
    if event.type == "medical_find" then
        event.status = "resolved"
        if choice == "accept" then
            profile.unlockedRelicIds.notes = true
            AddRelicInstance(run, "notes", event.memberId or run.leaderId)
            AddEvent(run, { type = "notes_choice", title = "这册医案该如何留下", blocking = false })
            State.AddLog(run, "家中收下批注医案，医术得以继续传下去。")
            return true, "批注医案已收入藏阁，也解锁了下一局资格。"
        end
        State.AddLog(run, "医案暂留在医馆，家中没有收下。")
        return true, "这次机会先记在家史里。"
    end
    if event.type == "plan_work" then
        event.status = "resolved"
        if choice == "accept" then
            if run.money < 10 then return false, "接下修缮前需要先备好 10 两工料。" end
            run.money = run.money + 18; run.reputation = run.reputation + 5
            State.AddLog(run, "依照营造图完成一桩修缮，净得 18 两并获 5 点声望。")
            return true, "修缮活已完成。"
        end
        State.AddLog(run, "家中婉拒了这次修缮活。")
        return true, "已婉拒。"
    end
    if event.type == "jade_search" then
        event.status = "resolved"
        if choice == "search" then
            if run.money < 8 then return false, "查访故人需要 8 两路费。" end
            run.money = run.money - 8; run.flags.jadeReunited = true; run.reputation = run.reputation + 8
            State.AddLog(run, "半枚玉佩终于找到另一半，故人的名字被重新记下。")
            return true, "重逢已写入家史，声望 +8。"
        end
        State.AddLog(run, "玉佩的线索被小心收好，等待下次查访。")
        return true, "线索暂存。"
    end
    if event.type == "school" then
        event.status = "resolved"
        if choice == "support" then
            if run.money < 6 then return false, "添置书本需要 6 两。" end
            run.money = run.money - 6
            for _, member in ipairs(run.members) do if member.alive and member.age < 18 then member.stats.learn = math.min(100, (member.stats.learn or 0) + 4) end end
            State.AddLog(run, "家中为孩子添置书本，在读的孩子学识各 +4。")
            return true, "书本已添置。"
        end
        State.AddLog(run, "今年先把书本钱留给日常开销。")
        return true, "已暂缓。"
    end
    if event.type == "community_request" then
        event.status = "resolved"
        if choice == "aid" then return Simulation.AidCommunity(run) end
        State.AddLog(run, "家中这次没有接下邻里的周转请求。")
        return true, "已婉拒。"
    end
    if event.type == "roof" then
        event.status = "resolved"
        if choice == "repair" then
            if run.money < 8 then return false, "修补屋顶需要 8 两。" end
            run.money = run.money - 8; run.reputation = run.reputation + 2
            State.AddLog(run, "屋顶修补妥当，邻里也记下了这份踏实。")
            return true, "屋顶已修补，声望 +2。"
        end
        State.AddLog(run, "屋顶暂未修补，来年仍要留心。")
        return true, "已暂缓。"
    end
    if event.type == "notes_choice" then
        event.status = "resolved"
        if choice == "print" then
            if run.money < 8 then return false, "刊印医案需要 8 两。" end
            run.money = run.money - 8; run.reputation = run.reputation + 8
            State.AddLog(run, "家中刊印批注医案，声望 +8。")
            return true, "医案已刊印。"
        end
        State.AddLog(run, "批注医案被郑重传给后人保管。")
        return true, "医案已传承。"
    end
    if event.type ~= "relic_resolution" then event.status = "resolved" return true, "事件已记录。" end
    local instance = RelicInstance(run, event.relicInstanceId)
    if not instance or instance.status == "sold" then event.status = "cancelled" return false, "物件已出售，后续不会结算。" end
    local relic = Data.Relic(instance.definitionId)
    event.status = "resolved"; instance.status = "held"; instance.stage = "completed"
    if choice == "restore" then
        if relic.unlock then
            profile.unlockedRelicIds[relic.unlock] = true
            AddRelicInstance(run, relic.unlock, instance.custodianId)
        end
        if relic.id == "ruler" then run.flags.rulerRestored = true elseif relic.id == "book" then run.flags.bookRestored = true elseif relic.id == "letter" then run.flags.promiseKept = true end
        State.AddLog(run, "你修复并安置了“" .. relic.name .. "”。" .. (relic.unlock and "“" .. Data.Relic(relic.unlock).name .. "”已进入本局藏阁，也解锁了下一局资格。" or "这段家史被完整记下。"))
        return true, "结果已写入家史与藏阁。"
    end
    State.AddLog(run, "“" .. relic.name .. "”的线索被妥善保存，暂不继续修复。")
    return true, "后续被保留在家史中。"
end

local function ApplyIncome(run, member, job, period, place)
    local money, grain = job.money or 0, job.grain or 0
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
        member.health = math.min(100, member.health + math.max(0, job.gain or 0))
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
        member.stats[job.stat] = math.min(100, (member.stats[job.stat] or 0) + math.max(0, gain))
    end
    if member.jobId == "home" then member.health = math.min(100, member.health + 1) end
    if member.jobId == "rest" then
        local recovery = (run.homeId == "estate" and 2 or run.homeId == "courtyard" and 1 or 0) + (run.habitId == "care" and 2 or 0)
        member.health = math.min(100, member.health + recovery)
    end
end

local function ResolveLivingCosts(run, living, period, place)
    local home = Data.Home(run.homeId)
    local baseExpense, carers = home.upkeep, 0
    for _, member in ipairs(living) do
        baseExpense = baseExpense + (member.age >= 18 and 4 or 2)
        if member.jobId == "home" then carers = carers + 1 end
    end
    local expense = math.floor(baseExpense * period.expense * (place.expenseMultiplier or 1))
    expense = math.max(0, expense - carers * 3)
    if run.habitId == "frugal" then expense = math.floor(expense * 0.9) end
    run.money = run.money - expense
    local foodNeed = 0
    for _, member in ipairs(living) do foodNeed = foodNeed + (member.age >= 18 and 2 or 1) end
    if run.grain >= foodNeed then run.grain = run.grain - foodNeed; run.metrics.foodYears = run.metrics.foodYears + 1 else
        local missing = foodNeed - run.grain; run.grain = 0
        local price = math.ceil(period.food * missing * (place.foodMultiplier or 1))
        if run.money >= price then
            run.money = run.money - price; run.metrics.foodYears = run.metrics.foodYears + 1
        else
            run.money = math.max(0, run.money)
            for _, member in ipairs(living) do member.health = math.max(0, member.health - 12) end
            State.AddLog(run, "口粮不足，全家体魄各减 12 点，度过了艰难的一年。")
        end
    end
    if run.money < 0 and run.grain > 0 then
        local sold = math.min(run.grain, math.ceil(-run.money / period.food))
        run.grain = run.grain - sold; run.money = run.money + sold * period.food
        State.AddLog(run, "卖出 " .. tostring(sold) .. " 石粮以补足日常开支。")
    end
    if run.money >= 0 then run.metrics.stable = run.metrics.stable + 1 else run.metrics.stable = 0 end
end

local function TryBirths(run)
    for _, parent in ipairs(run.members) do
        if parent.alive and parent.sex == "女" and parent.age >= 21 and parent.age <= 39 and parent.birthPlan and parent.spouseId and run.yearIndex - (parent.lastBirthYear or -5) >= 4 and run.money >= 16 then
            local spouse = State.FindMember(run.members, parent.spouseId)
            if spouse and spouse.alive and spouse.age >= 21 and spouse.age <= 60 and spouse.birthPlan and State.Random(run) < 0.27 then
                local childId = NextMemberId(run)
                local sex = State.Random(run, 0, 1) == 0 and "女" or "男"
                ---@type string[]
                local names = sex == "男" and Data.GivenNames.male or Data.GivenNames.female
                local child = {
                    id = childId, name = run.openingSnapshot.family .. names[State.Random(run, 1, #names)], sex = sex, age = 0,
                    parents = { parent.id, spouse.id }, spouseId = nil, talent = 2, focus = "general", experienceId = "none",
                    trait = "初生", jobId = "play", alive = true, health = 76, stats = State.Copy(Data.Experience("none").values),
                    jobYears = {}, birthPlan = true, lastBirthYear = -5, hadHomeAfterGuard = false,
                    generation = math.max(parent.generation or 1, spouse.generation or 1) + 1,
                    biography = { "大晟历 " .. tostring(run.calendar) .. " 年出生，父母是" .. parent.name .. "与" .. spouse.name .. "。" },
                }
                parent.lastBirthYear = run.yearIndex; spouse.lastBirthYear = run.yearIndex
                table.insert(run.members, child)
                State.AddLog(run, child.name .. "出生，家谱添了一页新名字。")
            end
        end
    end
end

local function QueueRoutineEvents(run)
    local hasChild, hasCraft = false, false
    for _, member in ipairs(run.members) do
        if member.alive and member.age < 18 then hasChild = true end
        if member.alive and member.jobId == "craft" then hasCraft = true end
    end
    if HasRelic(run, "plan") and hasCraft and run.yearIndex % 4 == 0 and run.flags.planWorkYear ~= run.yearIndex then
        run.flags.planWorkYear = run.yearIndex
        AddEvent(run, { type = "plan_work", title = "旧图纸上的修缮活", blocking = false })
    elseif HasRelic(run, "jade") and not run.flags.jadeReunited and run.yearIndex >= 3 and run.yearIndex % 3 == 0 then
        AddEvent(run, { type = "jade_search", title = "半枚玉佩的新线索", blocking = false })
    elseif hasChild and run.yearIndex % 5 == 0 then
        AddEvent(run, { type = "school", title = "孩子想多读一年书", blocking = false })
    elseif run.yearIndex % 5 == 0 then
        AddEvent(run, { type = "community_request", title = "邻里来求一份周转", blocking = false })
    elseif run.yearIndex % 7 == 0 then
        AddEvent(run, { type = "roof", title = "屋顶需要修补", blocking = false })
    end
end

local function MaybeShiftEra(run)
    if run.yearIndex < 6 or run.yearIndex - (run.eraSinceYear or 0) < 5 or State.Random(run) >= 0.22 then return end
    local nextIds = {
        unrest = { "rebuild" }, rebuild = { "peace", "strain" }, peace = { "strain" }, strain = { "peace", "unrest" },
    }
    ---@type string[]?
    local candidates = nextIds[run.eraId]
    if not candidates then return end
    local nextId = candidates[State.Random(run, 1, #candidates)]
    run.eraId = nextId; run.eraSinceYear = run.yearIndex
    State.AddLog(run, "时世转入“" .. Data.Period(nextId).name .. "”，往后的收支与粮价随之变化。")
end

local function ApplyPlaceBurden(run, living, place)
    if not place.healthPenalty then return end
    for _, member in ipairs(living) do member.health = math.max(0, member.health - place.healthPenalty) end
    State.AddLog(run, place.short .. "的劳顿使全家体魄各减 " .. tostring(place.healthPenalty) .. " 点。")
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
    ResolveLivingCosts(run, living, period, place)
    ApplyPlaceBurden(run, living, place)
    run.yearIndex = run.yearIndex + 1; run.calendar = run.calendar + 1
    TryBirths(run); AgeAndLife(run, living); QueueDueRelicEvents(run); HandleLeadership(run); MaybeShiftEra(run)
    if not HasRelic(run, "notes") and not run.flags.notesOffered then
        for _, member in ipairs(run.members) do
            if member.alive and (member.jobYears.doctor or 0) >= 4 and (member.stats.medicine or 0) >= 55 then
                run.flags.notesOffered = true
                AddEvent(run, { type = "medical_find", title = "医馆托来一册批注医案", memberId = member.id, blocking = false })
                break
            end
        end
    end
    QueueRoutineEvents(run)
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
    run.money = run.money - 15; run.reputation = run.reputation + 12 + (run.tieId == "neighbor" and 2 or 0); run.metrics.aid = run.metrics.aid + 1
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
    for _, entry in ipairs(Data.Endings) do
        local ending = entry --[[@as table<string, any>]]
        local ok = true
        for _, item in ipairs(Simulation.EndingProgress(run, ending["id"])) do if item[2] < item[3] then ok = false end end
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
