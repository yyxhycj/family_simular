local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Economy = require "Jiaye.Economy"

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

local function AddRelicInstance(run, definitionId, custodianId, source, executorId)
    if HasRelic(run, definitionId) then return nil end
    local instance = {
        instanceId = "relic-" .. tostring(#run.relicInstances + 1) .. "-" .. definitionId,
        definitionId = definitionId, status = "held", stage = "idle", source = source or "家中所得",
        custodianId = custodianId or run.leaderId, executorId = executorId, rewardState = "none",
    }
    table.insert(run.relicInstances, instance)
    return instance
end

local function LivingAdult(run, memberId)
    local member = State.FindMember(run.members, memberId)
    if member and member.alive and member.age >= 18 then return member end
    return nil
end

local function FindDefaultExecutor(run, instance)
    local current = LivingAdult(run, instance.executorId)
    if current then return current end
    local custodian = LivingAdult(run, instance.custodianId)
    if custodian then return custodian end
    local leader = LivingAdult(run, run.leaderId)
    if leader then return leader end
    for _, member in ipairs(run.members) do if member.alive and member.age >= 18 then return member end end
    return nil
end

local function RelicMemberIds(instance)
    local ids = {}
    if instance.executorId then table.insert(ids, instance.executorId) end
    if instance.custodianId and instance.custodianId ~= instance.executorId then table.insert(ids, instance.custodianId) end
    return ids
end

local function AddRelicFact(run, instance, text, detail)
    local fact = State.AddFact(run, "relic", text, RelicMemberIds(instance), detail or {})
    return fact
end

local function AwaitNewExecutor(run, instance, remainingYears, reason)
    instance.status = "held"
    instance.stage = "awaiting_executor"
    instance.remainingYears = math.max(1, remainingYears or 1)
    instance.dueYear = nil
    State.AddLog(run, Data.Relic(instance.definitionId).name .. "的" .. (reason or "办理") .. "因执行人不在，等待重新托付。")
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

function Simulation.IsFamilyCollapsed(run)
    return run.money == 0 and run.grain == 0
end

local function QueueDueRelicEvents(run)
    for _, instance in ipairs(run.relicInstances) do
        if instance.status == "investigating" then
            local executor = LivingAdult(run, instance.executorId)
            if not executor then
                AwaitNewExecutor(run, instance, (instance.dueYear or run.yearIndex) - run.yearIndex, "调查")
            elseif instance.dueYear and instance.dueYear <= run.yearIndex then
                instance.status = "awaiting_resolution"
                AddEvent(run, {
                    type = "relic_resolution", relicInstanceId = instance.instanceId, executorId = executor.id,
                    title = Data.Relic(instance.definitionId).name .. "有了新的线索", blocking = true,
                })
            end
        end
    end
end

function Simulation.GetJobReason(member, jobId)
    return State.CanUseJob(member, jobId)
end

function Simulation.SetJob(run, memberId, jobId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local member = State.FindMember(run.members, memberId)
    if not member or not member.alive then return false, "这位族人已无法安排。" end
    local ok, reason = State.CanUseJob(member, jobId)
    if not ok then return false, reason end
    if (member.jobYears.guard or 0) >= 3 and (jobId == "home" or jobId == "farm" or jobId == "rest") then member.hadHomeAfterGuard = true end
    local before = member.jobId
    if before == jobId then return false, "此人已经在做这份安排。" end
    member.jobId = jobId
    State.AddFact(run, "job", member.name .. "由“" .. Data.Jobs[before].name .. "”改为“" .. Data.Jobs[jobId].name .. "”。", { member.id }, { fromJobId = before, toJobId = jobId })
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
    if score >= 75 then member.examPassed = true; State.AddFact(run, "exam", member.name .. "应试得中，取得地方任职资格。", { member.id }, { passed = true }) return true, "应试通过。" end
    State.AddFact(run, "exam", member.name .. "此次应试未中，仍可继续读书后再试。", { member.id }, { passed = false })
    return true, "此次未中，盘缠已计入年鉴。"
end

local function CloseLeaderEvents(run, memberId)
    local resolved = false
    for _, event in ipairs(run.events) do
        if event.type == "leader" and event.status == "pending" then
            event.status = "resolved"; event.memberId = memberId; event.resolvedYear = run.yearIndex
            resolved = true
        end
    end
    return resolved
end

function Simulation.AppointLeader(run, memberId, reason)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local target = State.FindMember(run.members, memberId)
    if not target or not target.alive or target.age < 18 then return false, "族长必须是在世成年族人。" end
    if run.leaderId == memberId then
        -- 修复旧档中“已任命但事件仍待决”的状态，不重复任期或交接奖励。
        if CloseLeaderEvents(run, memberId) then return true, "现任族长已确认，继任待决已解除。" end
        return false, "此人已是族长。"
    end
    local old = State.FindMember(run.members, run.leaderId)
    local wasEffective = false
    for _, term in ipairs(run.leaderTerms) do
        if term.memberId == run.leaderId and not term.endYear then
            term.endYear = run.yearIndex
            term.effective = run.yearIndex - term.startYear >= 1
            wasEffective = term.effective
        end
    end
    local effective = false
    local term = { memberId = memberId, startYear = run.yearIndex, endYear = nil, effective = effective, reason = reason or "主动交接" }
    table.insert(run.leaderTerms, term)
    run.leaderId = memberId
    CloseLeaderEvents(run, memberId)
    if HasRelic(run, "newbook") and old and wasEffective then
        run.reputation = run.reputation + 3
        State.AddLog(run, "补完的族谱为这次有效交接添了 3 点声望。")
    end
    local members = old and { old.id, target.id } or { target.id }
    local fact = State.AddFact(run, "leadership", (old and old.name or "前任") .. "将族长之位交给了" .. target.name .. "。", members, { reason = term.reason, leaderTermStart = #run.leaderTerms })
    term.factId = fact.id
    return true, "族长已更替，其他族人的安排保持不变。"
end

function Simulation.Marry(run, memberId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
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
    State.AddFact(run, "marriage", member.name .. "与" .. spouse.name .. "成婚，新成员入谱。", { member.id, spouse.id })
    return true, "婚配已写入家谱。"
end

function Simulation.Adopt(run, guardianId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local guardian = State.FindMember(run.members, guardianId)
    if not guardian or not guardian.alive or guardian.age < 18 then return false, "需要一位在世成年监护人。" end
    if run.money < 8 then return false, "收养安置需要 8 两。" end
    local childId = NextMemberId(run)
    local child = { id = childId, name = run.openingSnapshot.family .. "小满", sex = State.Random(run, 0, 1) == 0 and "女" or "男", age = 6, parents = { guardian.id }, spouseId = nil, talent = 2, focus = "general", experienceId = "none", trait = "敏锐", jobId = "study", alive = true, health = 70, stats = State.Copy(Data.Experience("none").values), jobYears = {}, biography = { "大晟历 " .. tostring(run.calendar) .. " 年被收养，监护人为" .. guardian.name .. "。" }, adopted = true, birthPlan = true, lastBirthYear = -5, hadHomeAfterGuard = false, generation = State.Generation(run.members, guardian.id) + 1 }
    run.money = run.money - 8; table.insert(run.members, child)
    State.AddFact(run, "adoption", guardian.name .. "收养了" .. child.name .. "，孩子获得与其他族人同等的成长和继任资格。", { guardian.id, child.id })
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
    State.AddFact(run, "migration", "全家迁居至" .. place.short .. "，花费 " .. tostring(fee) .. " 两。", {}, { placeId = placeId, fee = fee, migrationCount = run.metrics.migrations })
    return true, "迁居已记入家史。"
end

function Simulation.BuyAsset(run, assetId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local price = Data.RuntimeAssetCosts[assetId]
    if not price then return false, "未知置办项目。" end
    if run.money < price then return false, "公库不足，需要 " .. tostring(price) .. " 两。" end
    if assetId == "workshop" and run.workshop then return false, "家中已有作坊。" end
    if assetId == "shop" and run.shop then return false, "家中已有商铺。" end
    run.money = run.money - price
    if assetId == "land" then run.land = run.land + 1 elseif assetId == "workshop" then run.workshop = true else run.shop = true end
    local assetName = ({ land = "田地", workshop = "木工作坊", shop = "小商铺" })[assetId]
    State.AddFact(run, "asset_purchase", "置办“" .. assetName .. "”，花费 " .. tostring(price) .. " 两。", {}, { assetId = assetId, price = price })
    return true, "置办完成。"
end

function Simulation.GrainPurchaseQuote(run, amount)
    local closed, message = IsClosed(run)
    if closed then return nil, message end
    local price, reason = Economy.GrainPurchasePrice(run, amount)
    if not price then return nil, reason end
    return { amount = math.tointeger(amount), price = price }
end

function Simulation.BuyGrain(run, amount)
    local quote, message = Simulation.GrainPurchaseQuote(run, amount)
    if not quote then return false, message end
    if run.money < quote.price then return false, "公库不足，购入 " .. tostring(quote.amount) .. " 石粮需要 " .. tostring(quote.price) .. " 两。" end
    run.money = run.money - quote.price
    run.grain = run.grain + quote.amount
    State.AddFact(run, "grain_purchase", "购入 " .. tostring(quote.amount) .. " 石粮，花费 " .. tostring(quote.price) .. " 两。", {}, { amount = quote.amount, price = quote.price })
    return true, "粮食已入库。"
end

function Simulation.SellRelic(run, instanceId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local relic = RelicInstance(run, instanceId)
    if not relic or relic.status == "sold" then return false, "此物件已不在家中。" end
    local definition = Data.Relic(relic.definitionId)
    relic.status = "sold"; relic.stage = "closed"; relic.pendingEventId = nil; run.money = run.money + (definition.saleValue or definition.cost * 2)
    for _, event in ipairs(run.events) do if event.relicInstanceId == relic.instanceId and event.status == "pending" then event.status = "cancelled" end end
    AddRelicFact(run, relic, "出售“" .. definition.name .. "”，未完成的故事到此为止。", { action = "sell", relicInstanceId = relic.instanceId })
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
    AddRelicFact(run, relic, "“" .. Data.Relic(relic.definitionId).name .. "改由" .. member.name .. "保管。", { action = "transfer", relicInstanceId = relic.instanceId })
    State.AddLog(run, "“" .. Data.Relic(relic.definitionId).name .. "”改由" .. member.name .. "保管。")
    return true, "保管人已更换。"
end

function Simulation.AssignRelicExecutor(run, instanceId, memberId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local relic = RelicInstance(run, instanceId)
    local member = LivingAdult(run, memberId)
    if not relic or relic.status == "sold" then return false, "此物件不在家中。" end
    if not member then return false, "执行人需要是在世成年人。" end
    relic.executorId = member.id
    AddRelicFact(run, relic, member.name .. "接下“" .. Data.Relic(relic.definitionId).name .. "”的" .. (Data.Relic(relic.definitionId).story.executor or "办理") .. "。", { action = "assign_executor", relicInstanceId = relic.instanceId })
    State.AddLog(run, member.name .. "接下“" .. Data.Relic(relic.definitionId).name .. "”的后续。")
    return true, "执行人已指定。"
end

function Simulation.InviteBranch(run, instanceId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local relic = RelicInstance(run, instanceId)
    if not relic or relic.definitionId ~= "newbook" or relic.status == "sold" then return false, "需要家中实际持有“补完的族谱”。" end
    if run.flags.branchInvited then return false, "这支旁系已经归家。" end
    if run.money < 12 then return false, "安置成年旁支需要 12 两。" end
    local executor = FindDefaultExecutor(run, relic)
    if not executor then return false, "需要一位在世成年人寻亲。" end
    relic.executorId = executor.id
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
    State.AddFact(run, "relic", executor.name .. "依照补完的族谱寻回" .. member.name .. "，旁支正式归家。", { executor.id, member.id }, { action = "invite_branch", relicInstanceId = relic.instanceId })
    State.AddLog(run, member.name .. "作为成年旁支归家，名字被正式写回族谱。")
    return true, "成年旁支已归家。"
end

function Simulation.PauseRelicInvestigation(run, instanceId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local instance = RelicInstance(run, instanceId)
    if not instance or instance.status == "sold" then return false, "此物件不在家中。" end
    if instance.status ~= "investigating" then return false, "当前没有可暂缓的调查。" end
    local definition = Data.Relic(instance.definitionId)
    instance.remainingYears = math.max(1, (instance.dueYear or run.yearIndex + 1) - run.yearIndex)
    instance.status = "held"; instance.stage = "paused"; instance.dueYear = nil
    AddRelicFact(run, instance, "“" .. definition.name .. "”的调查暂缓，保留余下线索。", { action = "pause", relicInstanceId = instance.instanceId })
    State.AddLog(run, definition.name .. "的调查暂缓，可随时继续。")
    return true, "调查已暂缓，未再扣费。"
end

function Simulation.ResumeRelicInvestigation(run, instanceId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local instance = RelicInstance(run, instanceId)
    if not instance or instance.status == "sold" then return false, "此物件不在家中。" end
    if instance.stage ~= "paused" and instance.stage ~= "awaiting_executor" then return false, "当前没有可恢复的调查。" end
    local executor = LivingAdult(run, instance.executorId)
    if not executor then return false, "需要重新指定一位在世成年人。" end
    instance.executorId = executor.id; instance.status = "investigating"; instance.stage = "resumed"
    instance.dueYear = run.yearIndex + math.max(1, instance.remainingYears or 1); instance.remainingYears = nil
    AddRelicFact(run, instance, executor.name .. "继续办理“" .. Data.Relic(instance.definitionId).name .. "”的线索。", { action = "resume", relicInstanceId = instance.instanceId })
    State.AddLog(run, executor.name .. "继续办理“" .. Data.Relic(instance.definitionId).name .. "”。")
    return true, "调查已恢复，保留原先等待。"
end

function Simulation.StartRelicInvestigation(run, instanceId, route, memberId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    if route == "pause" then return Simulation.PauseRelicInvestigation(run, instanceId) end
    local instance = RelicInstance(run, instanceId)
    if not instance or instance.status == "sold" then return false, "此物件不在家中。" end
    if instance.status == "investigating" then return false, "调查已经在进行。" end
    if instance.status == "awaiting_resolution" then return false, "线索已到，请先处理结果。" end
    if instance.rewardState == "granted" or instance.stage == "completed" then return false, "这件信物的故事已经完成。" end
    local definition = Data.Relic(instance.definitionId)
    if not definition.basic then return false, "这件信物有自己的后续入口。" end
    local option = definition.story and definition.story[route]
    if not option or not option.cost or not option.years then return false, "这条调查路线不存在。" end
    local executor = LivingAdult(run, memberId) or FindDefaultExecutor(run, instance)
    if not executor then return false, "需要指定一位在世成年人办理。" end
    if run.money < option.cost then return false, "“" .. definition.name .. "”的这条线索需要 " .. tostring(option.cost) .. " 两。" end
    instance.executorId = executor.id; instance.status = "investigating"; instance.stage = route
    instance.route = route; instance.dueYear = run.yearIndex + option.years; instance.remainingYears = nil
    AddRelicFact(run, instance, executor.name .. "为“" .. definition.name .. "”选择“" .. option.label .. "”。", { action = "investigate", route = route, cost = option.cost, dueYear = instance.dueYear, relicInstanceId = instance.instanceId })
    run.money = run.money - option.cost
    State.AddLog(run, executor.name .. "为“" .. definition.name .. "”安排“" .. option.label .. "”，花费 " .. tostring(option.cost) .. " 两。")
    return true, "调查已安排，主业不会被改动。"
end

function Simulation.StartJadeSearch(run, instanceId, memberId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local instance = RelicInstance(run, instanceId)
    if not instance or instance.definitionId ~= "jade" or instance.status == "sold" then return false, "需要家中实际持有“故人的半枚玉佩”。" end
    if run.flags.jadeReunited then return false, "玉佩的另一半已经寻回。" end
    for _, event in ipairs(run.events) do if event.type == "jade_search" and event.relicInstanceId == instanceId and event.status == "pending" then return false, "这条玉佩线索已经在等待决定。" end end
    local executor = LivingAdult(run, memberId) or FindDefaultExecutor(run, instance)
    if not executor then return false, "需要指定一位在世成年人查访。" end
    instance.executorId = executor.id; instance.stage = "awaiting_choice"
    local event = AddEvent(run, { type = "jade_search", relicInstanceId = instanceId, executorId = executor.id, title = "半枚玉佩的新线索", blocking = false })
    instance.pendingEventId = event.instanceId
    AddRelicFact(run, instance, executor.name .. "带着半枚玉佩查访故人。", { action = "jade_search", relicInstanceId = instance.instanceId })
    return true, "玉佩的去向已有线索，是否花路费查访由你决定。"
end

function Simulation.ResumeRelicStory(run, instanceId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local instance = RelicInstance(run, instanceId)
    if not instance or instance.status == "sold" then return false, "此物件不在家中。" end
    if instance.definitionId == "jade" then return Simulation.StartJadeSearch(run, instanceId) end
    if instance.definitionId == "notes" then
        local executor = LivingAdult(run, instance.executorId)
        if not executor then return false, "需要重新指定一位在世成年人。" end
        instance.executorId = executor.id; instance.stage = "awaiting_choice"
        local event = AddEvent(run, { type = "notes_choice", relicInstanceId = instance.instanceId, executorId = executor.id, title = "这册医案该如何留下", blocking = false })
        instance.pendingEventId = event.instanceId
        AddRelicFact(run, instance, executor.name .. "重新接下批注医案的去向决定。", { action = "resume_notes", relicInstanceId = instance.instanceId })
        return true, "医案已重新交由" .. executor.name .. "决定去向。"
    end
    if instance.definitionId == "plan" then
        local executor = LivingAdult(run, instance.executorId)
        if executor and executor.jobId ~= "craft" then return false, "需要把营造图交给在世手艺人。" end
        if not executor then return false, "需要一位在世手艺人才能继续营造图。" end
        instance.executorId = executor.id; instance.stage = "work_offered"
        local event = AddEvent(run, { type = "plan_work", relicInstanceId = instance.instanceId, executorId = executor.id, title = "旧图纸上的修缮活", blocking = false })
        instance.pendingEventId = event.instanceId
        return true, "新的修缮活已交给" .. executor.name .. "。"
    end
    return Simulation.ResumeRelicInvestigation(run, instanceId)
end

local function ActiveRelicEvent(run, event, definitionId)
    local instance = event.relicInstanceId and RelicInstance(run, event.relicInstanceId) or (definitionId and HasRelic(run, definitionId))
    if not instance or instance.status == "sold" then
        event.status = "cancelled"
        return nil, nil, "物件已出售或不在家中，后续不会结算。"
    end
    local assignedId = event.executorId or instance.executorId
    local executor = assignedId and LivingAdult(run, assignedId) or nil
    if not assignedId then executor = FindDefaultExecutor(run, instance) end
    if not executor then
        AwaitNewExecutor(run, instance, 1, "后续")
        event.status = "cancelled"
        return nil, nil, "执行人已不在，需要重新指定后再继续。"
    end
    instance.executorId = executor.id
    return instance, executor, nil
end

function Simulation.ResolveEvent(run, eventId, choice, profile)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local event = nil
    for _, item in ipairs(run.events) do if item.instanceId == eventId then event = item end end
    if not event or event.status ~= "pending" then return false, "这件事已处理或不存在。" end
    if event.type == "legacy_pending" then
        event.status = "resolved"
        State.AddFact(run, "migration", "确认了迁入家谱中的旧版家事：“" .. tostring(event.title or "未命名家事") .. "”。", {}, {
            action = "acknowledge_legacy_event", legacyType = event.legacyType, legacyDetail = State.Copy(event.legacyDetail or {}),
        })
        return true, "旧版待决家事已写入现有家史。"
    end
    if event.type == "growth" then
        local member = State.FindMember(run.members, event.memberId)
        if not member then
            event.cancelledMemberId = event.memberId
            event.memberId = nil
            event.status = "cancelled"
            return false, "这位族人的记录已不存在，成长提醒已作废。"
        end
        event.status = "resolved"
        if event.growthId == "promotion" then
            local job = Data.Jobs[event.jobId]
            State.AddFact(run, "growth", member.name .. (choice == "defer" and "暂缓出师，继续积累本领。" or "已具备“" .. (job and job.name or "新岗位") .. "”资格，等待本人安排。"), { member.id }, { growthId = event.growthId, jobId = event.jobId, choice = choice })
            return true, choice == "defer" and "已记录暂缓出师。" or "资格已记入经历，岗位仍由你确认。"
        end
        State.AddFact(run, "growth", member.name .. (choice == "defer" and "成年后的安排暂缓决定。" or "已成年，可以自行安排人生。"), { member.id }, { growthId = event.growthId, choice = choice })
        return true, choice == "defer" and "已记录暂缓安排。" or "成年节点已记入经历。"
    end
    if event.type == "medical_find" then
        if choice == "accept" then
            if HasRelic(run, "notes") then return false, "批注医案已经在家中，不能重复收下。" end
            event.status = "resolved"
            profile.unlockedRelicIds.notes = true
            local executor = LivingAdult(run, event.memberId) or LivingAdult(run, run.leaderId)
            local instance = AddRelicInstance(run, "notes", event.memberId or run.leaderId, "医馆托付", executor and executor.id)
            instance.stage = "awaiting_choice"
            local nextEvent = AddEvent(run, { type = "notes_choice", relicInstanceId = instance.instanceId, executorId = instance.executorId, title = "这册医案该如何留下", blocking = false })
            instance.pendingEventId = nextEvent.instanceId
            AddRelicFact(run, instance, (executor and executor.name or "家中") .. "从医馆接下批注医案。", { action = "receive_notes", relicInstanceId = instance.instanceId })
            State.AddLog(run, "家中收下批注医案，医术得以继续传下去。")
            return true, "批注医案已收入藏阁，也解锁了下一局资格。"
        end
        event.status = "resolved"
        State.AddLog(run, "医案暂留在医馆，家中没有收下。")
        return true, "这次机会先记在家史里。"
    end
    if event.type == "plan_work" then
        local instance, executor, problem = ActiveRelicEvent(run, event, "plan")
        if not instance then return false, problem end
        if choice == "accept" then
            if run.money < 10 then return false, "接下修缮前需要先备好 10 两工料。" end
            event.status = "resolved"; instance.pendingEventId = nil; instance.stage = "work_completed"; run.money = run.money + 18; run.reputation = run.reputation + 5
            AddRelicFact(run, instance, executor.name .. "依照营造图完成一桩修缮。", { action = "plan_work", relicInstanceId = instance.instanceId, money = 18, reputation = 5 })
            State.AddLog(run, executor.name .. "依照营造图完成一桩修缮，净得 18 两并获 5 点声望。")
            return true, "修缮活已完成。"
        end
        event.status = "resolved"; instance.pendingEventId = nil; instance.stage = "work_deferred"
        AddRelicFact(run, instance, executor.name .. "暂不接下营造图的修缮活。", { action = "plan_defer", relicInstanceId = instance.instanceId })
        State.AddLog(run, executor.name .. "暂不接下营造图的修缮活。")
        return true, "已婉拒。"
    end
    if event.type == "jade_search" then
        local instance, executor, problem = ActiveRelicEvent(run, event, "jade")
        if not instance then return false, problem end
        if choice == "search" then
            if run.money < 8 then return false, "查访故人需要 8 两路费。" end
            event.status = "resolved"; instance.pendingEventId = nil; instance.stage = "reunited"; run.money = run.money - 8; run.flags.jadeReunited = true; run.reputation = run.reputation + 8
            AddRelicFact(run, instance, executor.name .. "寻回玉佩的另一半，故人的名字被重新记下。", { action = "jade_reunion", relicInstanceId = instance.instanceId, money = -8, reputation = 8 })
            State.AddLog(run, executor.name .. "寻回玉佩的另一半，故人的名字被重新记下。")
            return true, "重逢已写入家史，声望 +8。"
        end
        event.status = "resolved"; instance.pendingEventId = nil; instance.stage = "clue_saved"
        AddRelicFact(run, instance, executor.name .. "把玉佩线索暂存，等待下次查访。", { action = "jade_defer", relicInstanceId = instance.instanceId })
        State.AddLog(run, executor.name .. "把玉佩线索小心收好，等待下次查访。")
        return true, "线索暂存。"
    end
    if event.type == "school" then
        if choice == "support" then
            if run.money < 6 then return false, "添置书本需要 6 两。" end
            event.status = "resolved"; run.money = run.money - 6
            for _, member in ipairs(run.members) do if member.alive and member.age < 18 then member.stats.learn = math.min(100, (member.stats.learn or 0) + 4) end end
            State.AddLog(run, "家中为孩子添置书本，在读的孩子学识各 +4。")
            return true, "书本已添置。"
        end
        event.status = "resolved"
        State.AddLog(run, "今年先把书本钱留给日常开销。")
        return true, "已暂缓。"
    end
    if event.type == "community_request" then
        if choice == "aid" then
            if run.money < 15 then return false, "接济邻里需要 15 两。" end
            local ok, message = Simulation.AidCommunity(run)
            if ok then event.status = "resolved" end
            return ok, message
        end
        event.status = "resolved"
        State.AddLog(run, "家中这次没有接下邻里的周转请求。")
        return true, "已婉拒。"
    end
    if event.type == "roof" then
        if choice == "repair" then
            if run.money < 8 then return false, "修补屋顶需要 8 两。" end
            event.status = "resolved"; run.money = run.money - 8; run.reputation = run.reputation + 2
            State.AddLog(run, "屋顶修补妥当，邻里也记下了这份踏实。")
            return true, "屋顶已修补，声望 +2。"
        end
        event.status = "resolved"
        State.AddLog(run, "屋顶暂未修补，来年仍要留心。")
        return true, "已暂缓。"
    end
    if event.type == "notes_choice" then
        local instance, executor, problem = ActiveRelicEvent(run, event, "notes")
        if not instance then return false, problem end
        if choice == "print" then
            if run.money < 8 then return false, "刊印医案需要 8 两。" end
            event.status = "resolved"; instance.pendingEventId = nil; instance.stage = "printed"; run.money = run.money - 8; run.reputation = run.reputation + 8
            AddRelicFact(run, instance, executor.name .. "刊印批注医案，留下公开的医术记录。", { action = "notes_print", relicInstanceId = instance.instanceId, money = -8, reputation = 8 })
            State.AddLog(run, executor.name .. "刊印批注医案，声望 +8。")
            return true, "医案已刊印。"
        end
        event.status = "resolved"; instance.pendingEventId = nil; instance.stage = "passed"
        AddRelicFact(run, instance, executor.name .. "把批注医案传给后人保管。", { action = "notes_pass", relicInstanceId = instance.instanceId })
        State.AddLog(run, executor.name .. "把批注医案郑重传给后人保管。")
        return true, "医案已传承。"
    end
    if event.type ~= "relic_resolution" then event.status = "resolved" return true, "事件已记录。" end
    local instance, executor, problem = ActiveRelicEvent(run, event)
    if not instance then return false, problem end
    local relic = Data.Relic(instance.definitionId)
    event.status = "resolved"; instance.pendingEventId = nil; instance.status = "held"; instance.stage = "completed"
    if choice == "restore" then
        if instance.rewardState == "granted" then return false, "这件信物的奖励已经登记。" end
        if relic.unlock then
            profile.unlockedRelicIds[relic.unlock] = true
            AddRelicInstance(run, relic.unlock, instance.custodianId, "修复“" .. relic.name .. "”", executor.id)
        end
        instance.rewardState = "granted"
        if relic.id == "ruler" then run.flags.rulerRestored = true elseif relic.id == "book" then run.flags.bookRestored = true elseif relic.id == "letter" then run.flags.promiseKept = true end
        AddRelicFact(run, instance, executor.name .. "完成“" .. relic.name .. "”的“" .. relic.story.restore .. "”。", { action = "restore", relicInstanceId = instance.instanceId, unlock = relic.unlock })
        State.AddLog(run, executor.name .. "完成“" .. relic.name .. "”的“" .. relic.story.restore .. "”。" .. (relic.unlock and "“" .. Data.Relic(relic.unlock).name .. "”已进入本局藏阁，也解锁了下一局资格。" or "这段家史被完整记下。"))
        return true, "结果已写入家史与藏阁。"
    end
    instance.stage = "clue_saved"
    AddRelicFact(run, instance, executor.name .. "选择“" .. (relic.story.defer or "暂存线索") .. "”。", { action = "defer", relicInstanceId = instance.instanceId })
    State.AddLog(run, "“" .. relic.name .. "”的线索被妥善保存，暂不继续修复。")
    return true, "后续被保留在家史中。"
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
                State.AddFact(run, "birth", child.name .. "出生，家谱添了一页新名字。", { parent.id, spouse.id, child.id })
            end
        end
    end
end

local function QueueGrowthEvents(run)
    run.flags.growthNotices = run.flags.growthNotices or {}
    local promotions = { apprentice = "craft", medical = "doctor", train = "guard", study = "teach" }
    for _, member in ipairs(run.members) do
        if member.alive and member.age == 18 and not run.flags.growthNotices["adult-" .. tostring(member.id)] then
            run.flags.growthNotices["adult-" .. tostring(member.id)] = true
            AddEvent(run, { type = "growth", growthId = "adult", memberId = member.id, title = member.name .. "已成年", blocking = false })
        end
        local targetJobId = promotions[member.jobId]
        if member.alive and targetJobId and not run.flags.growthNotices["promotion-" .. tostring(member.id) .. "-" .. targetJobId] then
            local ready = State.CanUseJob(member, targetJobId)
            if ready then
                run.flags.growthNotices["promotion-" .. tostring(member.id) .. "-" .. targetJobId] = true
                AddEvent(run, { type = "growth", growthId = "promotion", memberId = member.id, jobId = targetJobId, title = member.name .. "可以出师" , blocking = false })
            end
        end
    end
end

local function QueueRoutineEvents(run)
    local hasChild, craftMember = false, nil
    for _, member in ipairs(run.members) do
        if member.alive and member.age < 18 then hasChild = true end
        if member.alive and member.jobId == "craft" and not craftMember then craftMember = member end
    end
    local plan = HasRelic(run, "plan")
    if plan and craftMember and run.yearIndex % 4 == 0 and run.flags.planWorkYear ~= run.yearIndex then
        run.flags.planWorkYear = run.yearIndex
        plan.executorId = craftMember.id; plan.stage = "work_offered"
        local event = AddEvent(run, { type = "plan_work", relicInstanceId = plan.instanceId, executorId = craftMember.id, title = "旧图纸上的修缮活", blocking = false })
        plan.pendingEventId = event.instanceId
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
            for _, relic in ipairs(run.relicInstances) do if relic.custodianId == member.id and relic.status ~= "sold" then relic.custodianId = nil end end
            State.AddFact(run, "death", member.name .. "于大晟历 " .. tostring(run.calendar) .. " 年离世，生平被保留在家谱中；其保管物已回收入家中。", { member.id })
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
    local closed, message = IsClosed(run)
    if closed then return false, message end
    if #Simulation.PendingEvents(run) > 0 then return false, "请先处理待决事件。" end
    local living = Living(run)
    if #living == 0 then return false, "家谱已经落笔。" end
    local place = CurrentPlace(run)
    local yearStart = { money = run.money, grain = run.grain, land = run.land, members = {} }
    for _, member in ipairs(living) do table.insert(yearStart.members, { id = member.id, age = member.age, jobId = member.jobId }) end
    run.lastLedger = Economy.Settle(run)
    State.RecordAnnualLedger(run, run.lastLedger, yearStart)
    ApplyPlaceBurden(run, living, place)
    run.yearIndex = run.yearIndex + 1; run.calendar = run.calendar + 1
    TryBirths(run); AgeAndLife(run, living); QueueGrowthEvents(run); QueueDueRelicEvents(run); HandleLeadership(run); MaybeShiftEra(run)
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
        local ending = Data.Ending("last")
        if not ending then return false, "自然终章定义缺失。" end
        Simulation.FinalizeEnding(run, ending, profile)
    elseif Simulation.IsFamilyCollapsed(run) then
        local ending = Data.Ending("collapse")
        if not ending then return false, "家道终局定义缺失。" end
        Simulation.FinalizeEnding(run, ending, profile)
    else
        State.AddLog(run, "大晟历 " .. tostring(run.calendar) .. " 年结算完成。")
    end
    run.revision = run.revision + 1
    return true, "一年过去了。"
end

function Simulation.ResolveLeaderEvent(run, eventId, memberId)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local event = nil; for _, item in ipairs(run.events) do if item.instanceId == eventId then event = item end end
    if not event or event.type ~= "leader" or event.status ~= "pending" then return false, "继任事件已失效。" end
    return Simulation.AppointLeader(run, memberId, "前任离世")
end

function Simulation.AidCommunity(run)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    if run.money < 15 then return false, "接济邻里需要 15 两。" end
    run.money = run.money - 15; run.reputation = run.reputation + 12 + (run.tieId == "neighbor" and 2 or 0); run.metrics.aid = run.metrics.aid + 1
    State.AddFact(run, "community_aid", "家中接济了邻里，声望提升。", {}, { aidCount = run.metrics.aid, cost = 15, reputation = run.reputation })
    return true, "援助已被记入家史。"
end

local function FactIds(run, kind)
    local ids = {}
    for _, fact in ipairs(run.facts or {}) do if fact.kind == kind then table.insert(ids, fact.id) end end
    return ids
end

local function JobMemberIds(run, jobId, years)
    local ids = {}
    for _, member in ipairs(run.members) do
        if (member.jobYears[jobId] or 0) >= years then table.insert(ids, member.id) end
    end
    return ids
end

local function EffectiveHandoverFactIds(run)
    local ids = {}
    for _, term in ipairs(run.leaderTerms or {}) do
        if term.effective and term.factId then table.insert(ids, term.factId) end
    end
    return ids
end

local function MemberIds(members)
    local ids = {}
    for _, member in ipairs(members) do table.insert(ids, member.id) end
    return ids
end

local function Progress(label, current, required, measure, source, comparison)
    return { label, current, required, measure, source, comparison or "at_least" }
end

function Simulation.IsProgressMet(item)
    if item[6] == "at_most" then return item[2] <= item[3] end
    if item[6] == "equal" then return item[2] == item[3] end
    return item[2] >= item[3]
end

function Simulation.EndingProgress(run, endingId)
    local ledgers = FactIds(run, "annual_ledger")
    local leadership = EffectiveHandoverFactIds(run)
    local returnMembers = {}
    for _, member in ipairs(run.members) do if member.hadHomeAfterGuard then table.insert(returnMembers, member.id) end end
    local living = Living(run)
    local progress = {
        peaceful = { Progress("实际经营十年", run.yearIndex, 10, "累计", { source = "年度账本", factIds = ledgers }), Progress("连续五年生活充足", run.metrics.stable, 5, "连续", { source = "年度账本", factIds = ledgers }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        scholar = { Progress("两代教书", JobGenerations(run, "teach", 2), 2, "代际累计", { source = "家谱人物", memberIds = JobMemberIds(run, "teach", 2) }), Progress("积蓄", run.money, 200, "当前", { source = "公库" }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        merchant = { Progress("两代经商", JobGenerations(run, "trade", 3), 2, "代际累计", { source = "家谱人物", memberIds = JobMemberIds(run, "trade", 3) }), Progress("积蓄", run.money, 300, "当前", { source = "公库" }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        craft = { Progress("两代手艺", JobGenerations(run, "craft", 3), 2, "代际累计", { source = "家谱人物", memberIds = JobMemberIds(run, "craft", 3) }), Progress("作坊有人经营", run.workshop and JobYears(run, "craft") > 0 and 1 or 0, 1, "当前", { source = "家业与人物" }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        medical = { Progress("两代行医", JobGenerations(run, "doctor", 2), 2, "代际累计", { source = "家谱人物", memberIds = JobMemberIds(run, "doctor", 2) }), Progress("行医人年", JobYears(run, "doctor"), 12, "累计", { source = "家谱人物", memberIds = JobMemberIds(run, "doctor", 1) }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        grain = { Progress("实际经营", run.yearIndex, 15, "累计", { source = "年度账本", factIds = ledgers }), Progress("连续生活充足", run.metrics.foodYears, 10, "连续", { source = "年度账本", factIds = ledgers }), Progress("存粮", run.grain, 80, "当前", { source = "公库" }) },
        community = { Progress("实际经营", run.yearIndex, 12, "累计", { source = "年度账本", factIds = ledgers }), Progress("援助邻里", run.metrics.aid, 3, "累计", { source = "援助记录", factIds = FactIds(run, "community_aid") }), Progress("声望", run.reputation, 70, "当前", { source = "家族声望" }) },
        migration = { Progress("实际迁居", run.metrics.migrations, 1, "累计", { source = "迁居记录", factIds = FactIds(run, "migration") }), Progress("迁居后年数", math.max(0, run.yearIndex - run.metrics.lastMove), 8, "累计", { source = "迁居记录与年度账本", factIds = ledgers }), Progress("连续生活充足", run.metrics.stable, 5, "连续", { source = "年度账本", factIds = ledgers }) },
        ["return"] = { Progress("护卫后返家", #returnMembers, 1, "历史", { source = "家谱人物", memberIds = returnMembers }), Progress("实际经营", run.yearIndex, 8, "累计", { source = "年度账本", factIds = ledgers }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        promise = { Progress("完成旧约", run.flags.promiseKept and 1 or 0, 1, "历史", { source = "信物经历", factIds = FactIds(run, "relic") }), Progress("实际经营", run.yearIndex, 6, "累计", { source = "年度账本", factIds = ledgers }), Progress("连续生活充足", run.metrics.stable, 3, "连续", { source = "年度账本", factIds = ledgers }) },
        ruler = { Progress("修复旧尺", run.flags.rulerRestored and 1 or 0, 1, "历史", { source = "信物经历", factIds = FactIds(run, "relic") }), Progress("手艺人年", JobYears(run, "craft"), 8, "累计", { source = "家谱人物", memberIds = JobMemberIds(run, "craft", 1) }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        reunion = { Progress("重修族谱", run.flags.bookRestored and 1 or 0, 1, "历史", { source = "信物经历", factIds = FactIds(run, "relic") }), Progress("实际经营", run.yearIndex, 6, "累计", { source = "年度账本", factIds = ledgers }), Progress("真实交接", EffectiveHandovers(run), 1, "历史", { source = "族长任期", factIds = leadership }) },
        last = { Progress("在世族人归零", #living, 0, "当前", { source = "家谱人物", memberIds = MemberIds(living) }, "at_most") },
        collapse = {
            Progress("公库归零", run.money, 0, "当前", { source = "公库" }, "equal"),
            Progress("存粮归零", run.grain, 0, "当前", { source = "公库" }, "equal"),
        },
    }
    return progress[endingId] or {}
end

function Simulation.EndingEvidence(run, endingId)
    local evidence = {}
    for _, item in ipairs(Simulation.EndingProgress(run, endingId)) do
        table.insert(evidence, { label = item[1], current = item[2], required = item[3], measure = item[4], source = State.Copy(item[5]), comparison = item[6], met = Simulation.IsProgressMet(item) })
    end
    return evidence
end

function Simulation.IsEndingReady(run, endingId)
    local ending = Data.Ending(endingId)
    if not ending then return false end
    for _, item in ipairs(Simulation.EndingProgress(run, endingId)) do
        if not Simulation.IsProgressMet(item) then return false end
    end
    return true
end

function Simulation.AvailableEndings(run)
    local ready = {}
    for _, entry in ipairs(Data.Endings) do
        if not entry.automatic and Simulation.IsEndingReady(run, entry.id) then table.insert(ready, entry) end
    end
    return ready
end

local function QualifiedEndingIds(run)
    local ids = {}
    for _, ending in ipairs(Simulation.AvailableEndings(run)) do table.insert(ids, ending.id) end
    return ids
end

local function ClosePendingEvents(run, endingId)
    local ids = {}
    for _, event in ipairs(run.events) do
        if event.status == "pending" then
            event.status = "cancelled"
            event.closedByEndingId = endingId
            table.insert(ids, event.instanceId)
        end
    end
    return ids
end

function Simulation.FinalizeEnding(run, ending, profile)
    if run.ending then return false, "本局已经有主终章。" end
    if not ending then return false, "终章不存在。" end
    profile.endingRecords = profile.endingRecords or {}
    local closingEventIds = ClosePendingEvents(run, ending.id)
    local memberIds = {}
    for _, member in ipairs(run.members) do table.insert(memberIds, member.id) end
    local record = {
        id = ending.id, title = ending.title, type = ending.type, automatic = ending.automatic == true,
        year = run.calendar, summary = ending.desc, yearIndex = run.yearIndex, leaderId = run.leaderId,
        evidence = Simulation.EndingEvidence(run, ending.id), qualifiedEndingIds = QualifiedEndingIds(run),
        closingEventIds = closingEventIds,
    }
    local factText = record.automatic and (ending.automaticFact or "自然终局已写入家史。") or "选择“" .. ending.title .. "”作为这一局的主终章。"
    local fact = State.AddFact(run, "ending", factText, memberIds, {
        endingId = record.id, automatic = record.automatic, evidence = record.evidence,
        qualifiedEndingIds = record.qualifiedEndingIds, closingEventIds = closingEventIds,
    })
    record.factId = fact.id
    run.ending = record
    table.insert(profile.endingRecords, State.Copy(record))
    return true, "家业已落笔；人物与家史仍可回顾。"
end

function Simulation.ClaimEnding(run, endingId, profile)
    local closed, message = IsClosed(run)
    if closed then return false, message end
    local ending = Data.Ending(endingId)
    if not ending then return false, "终章不存在。" end
    if ending.automatic then return false, (ending.automaticHint or "自然终章会在满足条件后自动写入。") end
    if not Simulation.IsEndingReady(run, endingId) then return false, "条件尚未满足。" end
    return Simulation.FinalizeEnding(run, ending, profile)
end

return Simulation
