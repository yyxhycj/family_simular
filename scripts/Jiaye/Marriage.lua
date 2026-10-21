local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Art = require "Jiaye.Art"
local M = require "Jiaye.MarriageState"

local Marriage = { Rules = M }
local function Find(run, id) return State.FindMember(run.members, id) end
local function Family(run, id) return M.Find(run.marriage.households, id) end
local function Contract(run, id) return M.Find(run.marriage.contracts, id) end
local function Home(member) return member and member.alive and State.IsResident(member) end
local function Generation(member) return member.kinGeneration or member.generation or 1 end
local function Has(list, id) for _, value in ipairs(list or {}) do if value == id then return true end end return false end
local function Fare(left, right) return left == right and 0 or ((left == "village" or right == "village") and 4 or 8) end
local function Row(rows, id) for _, row in ipairs(rows) do if row.memberId == id and row.executed then return row end end end
local function Fact(run, text, ids, details) return State.AddFact(run, "kinship", text, ids or {}, details) end
local function Gain(member, stat, amount)
    local before = member.stats[stat] or 0
    member.stats[stat] = math.min(100, before + amount)
    return member.stats[stat] - before
end
local function NextId(run)
    local result = 0; for _, member in ipairs(run.members) do result = math.max(result, member.id) end
    return result + 1
end

local function RelatedFamily(run, member, householdId, seen)
    if not member or seen[member.id] then return false end
    seen[member.id] = true
    if member.natalHouseholdId == householdId then return true end
    for _, id in ipairs(member.parents or {}) do if RelatedFamily(run, Find(run, id), householdId, seen) then return true end end
    return false
end

function Marriage.Reason(run, memberId)
    if run.ending then return false, "本局已落笔。" end
    local member = Find(run, memberId)
    if not member or not member.alive then return false, "只有在世族人可以议亲。" end
    if not State.IsAdult(member) then return false, "婚配需满 " .. Data.AgeRules.adult .. " 岁。" end
    if not State.IsResident(member) then return false, "这位族人已在外成家。" end
    local spouse = Find(run, member.spouseId)
    if spouse and spouse.alive then return false, "已有在世配偶，可查看婚约与亲家。" end
    return true, ""
end

function Marriage.Candidates(run, memberId)
    if not Marriage.Reason(run, memberId) then return {} end
    local member, result = Find(run, memberId), {}
    for _, candidate in ipairs(run.marriage.candidates) do
        if candidate.status == "available" and candidate.age <= 60 and not RelatedFamily(run, member, candidate.householdId, {}) then
            table.insert(result, candidate)
        end
    end
    table.sort(result, function(left, right)
        local function Score(item)
            return math.abs(member.age - item.age) * 1000 + M.Hash(tostring(run.marriage.seed) .. ":" .. memberId .. ":" .. item.id) % 1000
        end
        return Score(left) < Score(right)
    end)
    local limit = 3
    for _, token in ipairs(run.marriage.introductions) do if token.expires >= run.yearIndex and token.remaining > 0 then limit = limit + token.remaining end end
    while #result > limit do table.remove(result) end
    return result
end

function Marriage.Offers(run, candidateId)
    local candidate = M.Find(run.marriage.candidates, candidateId)
    if not candidate or candidate.status ~= "available" then return {} end
    local family = Family(run, candidate.householdId)
    ---@type string[]
    local forms = candidate.stay and { "out", "dual" } or { "in", "dual", "out" }
    local offers = { { id = "plain", name = "各尽心意", forms = forms, duties = {}, detail = "按家资相赠，各自商议居所。" } }
    local duties = {}
    if family.need == "care" and family.patron.alive and family.patron.age >= 50 and not family.claimed.elder then
        duties = { { kind = "care", name = "接长辈同住", required = 3, window = 3 } }
        forms = { "in" }
    elseif (family.need == "labor" or family.need == "succession") and family.assets.land > 0 then
        duties = { { kind = "land", name = "守业耕田", required = 5, window = 7 } }
    else
        duties = { { kind = "study", name = "留学守约", required = 2, window = 4, job = candidate.focus == "skill" and "apprentice" or "study", rebate = 4 } }
        forms = candidate.stay and { "dual" } or { "in", "dual" }
    end
    table.insert(offers, { id = "pledge", name = "相助成家", forms = forms, duties = duties, detail = "接受亲家所托，获得对应资助。" })
    return offers
end

local function AidReserve(family)
    if family.claimed.aid then return nil, 0, 0 end
    local kind = family.aidKind
    if kind == "money" then return { kind = kind, amount = 4, remaining = 3 }, 12, 0 end
    if kind == "grain" then return { kind = kind, amount = 2, remaining = 2 }, 0, 4 end
    return { kind = kind, amount = 2, remaining = 3 }, 0, 0
end

function Marriage.Quote(run, memberId, input)
    local ok, reason = Marriage.Reason(run, memberId)
    if not ok then return nil, reason end
    input = input or {}
    local member, candidate = Find(run, memberId), M.Find(run.marriage.candidates, input.candidateId)
    if not candidate or candidate.status ~= "available" then return nil, "该对象已离开议亲名单。" end
    local shown = false; for _, item in ipairs(Marriage.Candidates(run, memberId)) do if item.id == candidate.id then shown = true end end
    if not shown then return nil, "需要先获得这位对象的引见。" end
    local family = Family(run, candidate.householdId)
    local offer = M.Find(Marriage.Offers(run, candidate.id), input.offerId)
    local wedding = M.Find(M.Weddings, input.weddingId)
    if not offer or not wedding or not Has(offer.forms, input.form) then return nil, "请选择婚约、居所和礼仪。" end
    if input.form == "dual" and input.childHome ~= "home" and input.childHome ~= "external" then return nil, "请约定孩子归属。" end
    if input.aidTargetId and not Home(Find(run, input.aidTargetId)) then return nil, "资助受惠人需在家且在世。" end
    if input.form == "out" then
        if input.aidTargetId == memberId then return nil, "请为迁出后的资助选择一位留家受惠人。" end
        local adults = 0
        for _, person in ipairs(run.members) do if Home(person) and State.IsAdult(person) and person.id ~= memberId then adults = adults + 1 end end
        if adults == 0 then return nil, "本家至少需留一位在世成年人。" end
        if run.leaderId == memberId then return nil, "迁出前请先交接族长之位。" end
        for _, relic in ipairs(run.relicInstances) do if relic.custodianId == memberId then return nil, "迁出前请先交接保管的信物。" end end
        if Marriage.Busy(run, memberId) then return nil, "迁出前请先暂停正在办理的事务。" end
    end
    local best = 0; for _, amount in pairs(candidate.stats) do best = math.max(best, amount) end
    local base = ({ 2, 8, 14, 24 })[family.wealth] + (best >= 60 and 12 or best >= 35 and 6 or 0) + (candidate.talent >= 5 and 8 or candidate.talent >= 4 and 4 or 0)
    local match = member.stats[candidate.focus] or 0
    local discount = (match >= 70 and 6 or match >= 50 and 4 or match >= 35 and 2 or 0)
        + (run.reputation >= 60 and 4 or run.reputation >= 30 and 2 or 0)
    local relevantJob = ({ learn = "study", skill = "craft", medicine = "doctor", trade = "trade", martial = "guard" })[candidate.focus]
    if (member.jobYears[relevantJob] or 0) >= 2 then discount = discount + 2 end
    discount = math.min(8, discount)
    local duties, rebate, housing, careMoney, careGrain = State.Copy(offer.duties), 0, input.form == "in" and 4 or 0, 0, 0
    for _, duty in ipairs(duties) do
        if duty.kind == "study" then rebate = math.min(4, math.max(0, base - discount)); duty.rebate = rebate end
        if duty.kind == "care" then housing = housing + 4; careMoney = 6; careGrain = 6 end
    end
    local aid, aidMoney, aidGrain = AidReserve(family)
    if family.assets.money < careMoney + aidMoney or family.assets.grain < careGrain + aidGrain then return nil, "亲家现有家资已不足以兑现这份婚约。" end
    local giftMoney = math.min(12, math.floor((family.assets.money - careMoney - aidMoney) / 5))
    local giftGrain = math.min(6, math.floor((family.assets.grain - careGrain - aidGrain) / 3))
    local transfer = math.max(0, base - discount)
    if input.form == "dual" then transfer = math.floor(transfer * 0.7) end
    if input.form == "out" then transfer = math.floor(transfer * 0.5) end
    rebate = math.min(rebate, transfer); transfer = transfer - rebate
    for _, duty in ipairs(duties) do if duty.kind == "study" then duty.rebate = rebate end end
    local route = Fare(family.placeId, run.placeId)
    local media = run.tieId == "neighbor" and 0 or 2
    local first = not member.weddingRewardClaimed
    local moneyCost = media + wedding.money + transfer + housing + route
    local weddingGift = first and wedding.gift or 0
    local object
    if not family.claimed.heritage then
        if family.blueprint then object = { kind = "blueprint" }
        elseif family.traitId then object = { kind = "trait", traitId = family.traitId }
        elseif family.assets.book then object = { kind = "book", charges = 3 }
        end
    end
    local balance = run.money - moneyCost + giftMoney + weddingGift
    local grain = run.grain - wedding.grain + giftGrain
    return {
        memberId = memberId, candidateId = candidate.id, householdId = family.id, offerId = offer.id, form = input.form,
        childHome = input.form == "in" and "home" or input.form == "out" and "external" or input.childHome,
        weddingId = wedding.id, duties = duties, aid = aid, object = object, aidTargetId = input.aidTargetId or (input.form == "out" and run.leaderId or nil),
        costs = { media = media, wedding = wedding.money, transfer = transfer, housing = housing, route = route }, discount = discount, rebate = rebate,
        moneyCost = moneyCost, grainCost = wedding.grain, giftMoney = giftMoney, giftGrain = giftGrain, weddingGift = weddingGift,
        reputation = first and wedding.reputation or 0, reserveMoney = careMoney + aidMoney, reserveGrain = careGrain + aidGrain,
        money = balance, grain = grain, incoming = input.form == "in" and (careMoney > 0 and 2 or 1) or 0, outgoing = input.form == "out" and 1 or 0,
        affordable = run.money >= moneyCost and run.grain >= wedding.grain and balance > 0 and grain > 0,
    }
end

local function NewPerson(run, source, residence, placeId)
    local member = {
        id = NextId(run), name = source.name, sex = source.sex or "男", age = source.age,
        parents = {}, talent = source.talent or 2, focus = source.focus or "general", experienceId = "basic", trait = source.wish or "重情",
        jobId = source.age >= 60 and "rest" or "home", alive = true, health = source.health or 72,
        stats = State.Copy(source.stats or Data.Experience("basic").values), jobYears = {}, biography = {},
        residence = residence, residencePlaceId = placeId, birthPlan = true, lastBirthYear = -5, hadHomeAfterGuard = false,
    }
    Art.Assign(member, run.runId); table.insert(run.members, member)
    return member
end

function Marriage.Marry(run, memberId, input)
    local quote, reason = Marriage.Quote(run, memberId, input)
    if not quote then return false, reason end
    if not quote.affordable then return false, "现有钱粮不足以支付明列的费用并留有余粮。" end
    local member, family = Find(run, memberId), Family(run, quote.householdId)
    member.kinGeneration = Generation(member)
    local candidate = M.Find(run.marriage.candidates, quote.candidateId)
    for rank, item in ipairs(Marriage.Candidates(run, memberId)) do
        if item.id == candidate.id and rank > 3 then
            for _, token in ipairs(run.marriage.introductions) do
                if token.expires >= run.yearIndex and token.remaining > 0 then token.remaining = token.remaining - 1; break end
            end
        end
    end
    local residence = quote.form == "in" and "home" or "external"
    local spouse = NewPerson(run, candidate, residence, residence == "home" and run.placeId or family.placeId)
    spouse.kinGeneration = member.kinGeneration
    spouse.natalHouseholdId = family.id
    if family.patron.memberId then spouse.parents = { family.patron.memberId } end
    local contract = State.Copy(quote)
    contract.id = "marriage-" .. (#run.marriage.contracts + 1)
    contract.spouseId = spouse.id; contract.year = run.yearIndex; contract.placeId = run.placeId; contract.status = "married"
    if member.spouseId then
        member.formerSpouses = member.formerSpouses or {}; table.insert(member.formerSpouses, member.spouseId)
    end
    member.spouseId = spouse.id; spouse.spouseId = member.id
    member.marriageId = contract.id; spouse.marriageId = contract.id
    member.weddingRewardClaimed = true; spouse.weddingRewardClaimed = true
    member.birthPlan = true
    if quote.form == "out" then member.residence = "external"; member.residencePlaceId = family.placeId end
    run.money = quote.money; run.grain = quote.grain; run.reputation = run.reputation + quote.reputation
    family.assets.money = family.assets.money + quote.costs.transfer - quote.giftMoney - quote.reserveMoney
    family.assets.grain = family.assets.grain - quote.giftGrain - quote.reserveGrain
    candidate.status = "married"; candidate.memberId = spouse.id
    if quote.aid then
        family.claimed.aid = contract.id
        contract.aid.targetId = quote.aidTargetId or (quote.form == "in" and spouse.id or member.id)
        contract.aid.expires = run.yearIndex + 6
    end
    for _, duty in ipairs(contract.duties) do
        duty.progress = 0; duty.status = "active"; duty.started = run.yearIndex; duty.deadline = run.yearIndex + duty.window; duty.extensions = 0
        if duty.kind == "care" then
            local elder = NewPerson(run, { name = family.patron.name, age = family.patron.age }, "home", run.placeId)
            elder.kinGeneration = math.max(1, spouse.kinGeneration - 1)
            duty.elderId = elder.id; duty.money = 6; duty.grain = 6; duty.penalties = 0; family.patron.memberId = elder.id
            spouse.parents = { elder.id }; family.claimed.elder = contract.id
        elseif duty.kind == "land" then
            family.assets.land = family.assets.land - 1; run.land = run.land + 1; duty.title = "restricted"
        else duty.targetId = quote.form == "in" and spouse.id or member.id end
    end
    if quote.object then
        family.claimed.heritage = contract.id
        local holder = quote.form == "in" and spouse.id or member.id
        if quote.object.kind == "trait" then
            table.insert(run.marriage.traditions, { id = contract.id .. "-tradition", kind = quote.object.traitId, holderId = spouse.id, lineage = contract.id, generationUses = {}, completedProjects = {} })
        else
            table.insert(run.marriage.objects, { id = contract.id .. "-object", kind = quote.object.kind, holderId = holder, charges = quote.object.charges, contractId = contract.id })
            if quote.object.kind == "book" then family.assets.book = false else family.blueprint = false end
        end
    end
    table.insert(run.marriage.contracts, contract)
    State.NormalizeGenerations(run.members)
    State.AddFact(run, "marriage", member.name .. "与" .. spouse.name .. "结亲，约定“" .. M.Find(M.Forms, quote.form).name .. "”。花费" .. quote.moneyCost .. "两、" .. quote.grainCost .. "石，亲家相赠" .. quote.giftMoney .. "两、" .. quote.giftGrain .. "石。", { member.id, spouse.id }, { contractId = contract.id, marriageQuote = State.Copy(quote), joinedMemberId = residence == "home" and spouse.id or nil })
    return true, "婚约、居所与亲家往来已入谱。"
end

function Marriage.Busy(run, memberId, ownId)
    for _, task in ipairs(run.relicTasks or {}) do
        if task.status == "active" and (task.executorId == memberId or Has(task.participantIds, memberId)) then return "正在办理信物事务。" end
    end
    for id, task in pairs(run.relicExternalProjects or {}) do
        if id ~= ownId and task.status == "active" and Has(task.participantIds, memberId) then return "正在办理“" .. tostring((task.metadata or {}).name or id) .. "”。" end
    end
end

local function Slot(run, id, actorIds, name, status)
    run.relicExternalProjects = run.relicExternalProjects or {}
    local project = run.relicExternalProjects[id] or { id = id, projectId = id, external = true, acceptedYear = run.yearIndex, workFacts = {} }
    project.participantIds = actorIds; project.attachedInstanceIds = {}; project.metadata = { name = name }; project.status = status
    run.relicExternalProjects[id] = project
end

function Marriage.ProjectReason(run, contractId, kind, actorId)
    if run.ending then return false, "本局已落笔。" end
    local contract, actor, definition = Contract(run, contractId), Find(run, actorId), M.Projects[kind]
    if not contract or not definition or not Home(actor) then return false, "请选择一位在家办理人。" end
    if kind ~= "tutor" and kind ~= "doctor" and not State.IsAdult(actor) then return false, "办理人需年满18岁。" end
    local family = Family(run, contract.householdId)
    if family.patron.role ~= kind then return false, "亲家没有这项身份。" end
    if not family.patron.alive or not family.patron.active then return false, "亲家已离任或离世，无法发起新的引荐。" end
    if run.yearIndex >= contract.year + definition.window then return false, "这项亲家机会已过期限。" end
    local quota = family.projects[kind] or { count = 0, nextYear = 0 }
    if quota.count >= (definition.limit or 1) or run.yearIndex < quota.nextYear then return false, "亲家共享名额已用尽或尚在间隔期。" end
    for _, project in ipairs(run.marriage.projects) do if project.householdId == family.id and project.kind == kind and (project.status == "active" or project.status == "paused") then return false, "亲家已有同类事务在办。" end end
    if actor.jobId ~= definition.job then return false, "需实际安排“" .. Data.Jobs[definition.job].name .. "”。" end
    if not State.CanUseJob(actor, actor.jobId) then return false, "办理人尚不满足这份安排的条件。" end
    if definition.statReq and (actor.stats[definition.statReq] or 0) < definition.min then return false, Data.FocusNames[definition.statReq] .. "需达到" .. definition.min .. "。" end
    if kind == "officer" and actor.health < 50 then return false, "护送需要体魄50。" end
    if kind == "artisan" then
        if not run.workshop then return false, "需先拥有作坊。" end
        local blueprint = false
        for _, object in ipairs(run.marriage.objects) do if object.contractId == contractId and object.kind == "blueprint" and not object.consumed and Home(Find(run, object.holderId)) then blueprint = true end end
        if not blueprint then return false, "这份婚约没有可用的改坊图纸。" end
    end
    if run.money < definition.fee then return false, "需支付" .. definition.fee .. "两。" end
    local busy = Marriage.Busy(run, actorId)
    if busy then return false, busy end
    return true, ""
end

function Marriage.StartProject(run, contractId, kind, actorId)
    local ok, reason = Marriage.ProjectReason(run, contractId, kind, actorId)
    if not ok then return false, reason end
    local contract, definition = Contract(run, contractId), M.Projects[kind]
    local family = Family(run, contract.householdId)
    local id = "kin-project-" .. (#run.marriage.projects + 1)
    local project = { id = id, kind = kind, contractId = contractId, householdId = family.id, actorId = actorId, started = run.yearIndex, deadline = math.min(contract.year + definition.window, run.yearIndex + (definition.deadline or definition.window)), progress = 0, status = "active", paid = definition.fee, unspent = (kind == "merchant" or kind == "artisan") and definition.fee or 0 }
    table.insert(run.marriage.projects, project)
    family.projects[kind] = { count = ((family.projects[kind] or {}).count or 0) + 1, nextYear = run.yearIndex + (definition.cooldown or definition.window) }
    if kind == "artisan" then for _, object in ipairs(run.marriage.objects) do if object.contractId == contractId and object.kind == "blueprint" then object.consumed = true end end end
    run.money = run.money - definition.fee
    Slot(run, id, { actorId }, definition.name, "active")
    Fact(run, Find(run, actorId).name .. "接下“" .. definition.name .. "”，支付" .. definition.fee .. "两。", { actorId }, { projectId = id })
    return true, "亲家事务已开始。"
end

function Marriage.ProjectAction(run, projectId, action)
    if run.ending then return false, "本局已落笔。" end
    local project = M.Find(run.marriage.projects, projectId)
    if not project or (project.status ~= "active" and project.status ~= "paused") then return false, "该事务已结束。" end
    if action == "pause" and project.status == "active" then project.status = "paused"
    elseif action == "resume" and project.status == "paused" then
        if run.yearIndex >= project.deadline or not Home(Find(run, project.actorId)) then return false, "办理人或期限条件已失效。" end
        local reason = Marriage.Busy(run, project.actorId, project.id); if reason then return false, reason end
        project.status = "active"
    elseif action == "cancel" then
        project.status = "cancelled"; run.money = run.money + project.unspent; project.refunded = project.unspent; project.unspent = 0
    else return false, "当前无法进行这项操作。" end
    Slot(run, project.id, { project.actorId }, M.Projects[project.kind].name, project.status)
    Fact(run, "“" .. M.Projects[project.kind].name .. "”" .. ({ pause = "已暂停，期限继续计算。", resume = "已恢复。", cancel = "已结束，退回未用款" .. (project.refunded or 0) .. "两。" })[action], { project.actorId }, { projectId = project.id })
    return true, "事务状态已保存。"
end

function Marriage.Tradition(run, memberId)
    for _, tradition in ipairs(run.marriage.traditions) do if tradition.holderId == memberId then return tradition end end
end

function Marriage.SetAidTarget(run, contractId, memberId)
    if run.ending then return false, "本局已落笔。" end
    local contract, member = Contract(run, contractId), Find(run, memberId)
    if not contract or not contract.aid or contract.aid.remaining <= 0 or run.yearIndex >= contract.aid.expires or not Home(member) then return false, "资助或受惠人条件不足。" end
    contract.aid.targetId = memberId
    Fact(run, "亲家后续资助交由" .. member.name .. "承接，剩余名额与期限沿用婚约。", { memberId }, { contractId = contractId })
    return true, "资助受惠人已指定。"
end

function Marriage.ReaderReason(run, traditionId, memberId)
    local tradition, member = M.Find(run.marriage.traditions, traditionId), Find(run, memberId)
    local holder = tradition and Find(run, tradition.holderId)
    if not tradition or tradition.kind ~= "farming" or not Home(member) or not Home(holder) or member.age < Data.AgeRules.study or Generation(member) ~= Generation(holder) then return false, "请选择持有人同代、达到读书年龄的在家族人。" end
    local source = tradition
    for _, item in ipairs(run.marriage.traditions) do if item.lineage == tradition.lineage then source = item; break end end
    local uses = source.generationUses[tostring(Generation(member))]
    if uses and uses.used > 0 and uses.targetId ~= memberId then return false, "本代已有实际受惠的读书人。" end
    return true, ""
end

function Marriage.SetReader(run, traditionId, memberId)
    if run.ending then return false, "本局已落笔。" end
    local ok, reason = Marriage.ReaderReason(run, traditionId, memberId)
    if not ok then return false, reason end
    local tradition = M.Find(run.marriage.traditions, traditionId)
    for _, item in ipairs(run.marriage.traditions) do if item.lineage == tradition.lineage then tradition = item; break end end
    local member = Find(run, memberId)
    member.kinGeneration = Generation(member)
    local generation = tostring(member.kinGeneration)
    local uses = tradition.generationUses[generation] or { used = 0 }
    uses.targetId = memberId; tradition.generationUses[generation] = uses
    Fact(run, "本代耕读名额约定交由" .. Find(run, memberId).name .. "，按实际读书年使用。", { memberId })
    return true, "本代读书人已指定。"
end

function Marriage.TeachReason(run, mentorId, studentId)
    local mentor, student = Find(run, mentorId), Find(run, studentId)
    local tradition = Marriage.Tradition(run, mentorId)
    if not Home(mentor) or not Home(student) or not tradition or mentorId == studentId then return false, "需要同住的家法持有人和受教人。" end
    if Marriage.Tradition(run, studentId) then return false, "此人已有一项家法。" end
    if tradition.kind == "farming" and (mentor.age - student.age < 5 or student.age < Data.AgeRules.study) then return false, "耕读传习需师长年长5岁，受教人达到读书年龄。" end
    if tradition.kind == "diet" and (student.age < 12 or student.stats.medicine < 25) then return false, "药膳传习需12岁、医术25。" end
    if tradition.kind == "thrift" and (student.age < 18 or student.stats.trade < 25) then return false, "持家传习需18岁、经营25。" end
    if tradition.kind == "trust" and student.age < 18 then return false, "重诺传习需18岁。" end
    for _, lesson in ipairs(run.marriage.lessons) do
        if lesson.status == "active" and (lesson.mentorId == mentorId or lesson.studentId == studentId) then return false, "师生已有进行中的传习，请先暂停。" end
    end
    local busy = Marriage.Busy(run, mentorId) or (tradition.kind ~= "trust" and Marriage.Busy(run, studentId))
    if busy then return false, busy end
    return true, ""
end

function Marriage.Teach(run, mentorId, studentId)
    if run.ending then return false, "本局已落笔。" end
    local ok, reason = Marriage.TeachReason(run, mentorId, studentId)
    if not ok then return false, reason end
    Find(run, mentorId).kinGeneration = Generation(Find(run, mentorId))
    Find(run, studentId).kinGeneration = Generation(Find(run, studentId))
    local tradition = Marriage.Tradition(run, mentorId)
    local lesson
    for _, item in ipairs(run.marriage.lessons) do if item.studentId == studentId and item.kind == tradition.kind and item.status == "paused" then lesson = item end end
    if not lesson then
        lesson = { id = "kin-lesson-" .. (#run.marriage.lessons + 1), studentId = studentId, kind = tradition.kind, lineage = tradition.lineage, progress = 0, years = {}, projectKinds = {}, generationUses = {} }
        table.insert(run.marriage.lessons, lesson)
    end
    lesson.mentorId = mentorId; lesson.status = "active"
    Slot(run, lesson.id, { mentorId }, M.Traits[lesson.kind].name .. "传习", "active")
    Fact(run, Find(run, mentorId).name .. "开始向" .. Find(run, studentId).name .. "传习“" .. M.Traits[lesson.kind].name .. "”。", { mentorId, studentId })
    return true, "传习已安排，原有进度会保留。"
end

function Marriage.PauseLesson(run, id)
    if run.ending then return false, "本局已落笔。" end
    local lesson = M.Find(run.marriage.lessons, id)
    if not lesson or lesson.status ~= "active" then return false, "当前传习未进行。" end
    lesson.status = "paused"; Slot(run, id, { lesson.mentorId }, M.Traits[lesson.kind].name .. "传习", "paused")
    return true, "传习已暂停。"
end

function Marriage.GiveObject(run, objectId, targetId)
    if run.ending then return false, "本局已落笔。" end
    local object, target = M.Find(run.marriage.objects, objectId), Find(run, targetId)
    if not object or object.consumed or (object.charges and object.charges <= 0) or not Home(target) then return false, "物件或接手人条件不足。" end
    local holder = Find(run, object.holderId)
    if holder and holder.alive and not State.IsResident(holder) then return false, "物件由在外族人持有，需先处理两家团聚。" end
    object.holderId = targetId
    Fact(run, target.name .. "接手亲家留下的" .. (object.kind == "book" and "书册" or "图纸") .. "。", { targetId }, { objectId = objectId })
    return true, "保管人与剩余用途已保存。"
end

function Marriage.ExamBonus(run, memberId, consume)
    local year, chosen = run.yearIndex, nil
    for _, project in ipairs(run.marriage.projects) do
        local contract = Contract(run, project.contractId)
        if project.kind == "tutor" and project.actorId == memberId and project.progress >= 1 and not project.examUsed and year < contract.year + 6 then chosen = project; break end
    end
    if chosen and consume then chosen.examUsed = true end
    return chosen and 0.08 or 0
end

local function NotifyProjectSuccess(run, project, year)
    for _, tradition in ipairs(run.marriage.traditions) do
        if tradition.kind == "trust" and tradition.holderId == project.actorId and not tradition.completedProjects[project.kind] then
            local count = 0; for _ in pairs(tradition.completedProjects) do count = count + 1 end
            if count < 3 then run.reputation = run.reputation + 2; tradition.completedProjects[project.kind] = true end
        end
    end
    for _, lesson in ipairs(run.marriage.lessons) do
        if lesson.status == "active" and lesson.kind == "trust" and (lesson.studentId == project.actorId or lesson.mentorId == project.actorId)
            and Home(Find(run, lesson.mentorId)) and Home(Find(run, lesson.studentId)) and not lesson.projectKinds[project.kind] and not lesson.years[tostring(year)] then
            lesson.projectKinds[project.kind] = true; lesson.years[tostring(year)] = true; lesson.progress = lesson.progress + 1
        end
    end
end

local function CompleteProject(run, project, year, result)
    local definition = M.Projects[project.kind]
    project.status = "completed"; project.completedYear = year; project.unspent = 0
    Slot(run, project.id, { project.actorId }, definition.name, "completed")
    if definition.reward then run.money = run.money + definition.reward; result.money = result.money + definition.reward end
    if project.kind == "clan" then table.insert(run.marriage.introductions, { remaining = 2, expires = year + 3 }); M.GenerateHousehold(run) end
    if project.kind == "artisan" then run.marriage.workshopImproved = true end
    NotifyProjectSuccess(run, project, year)
    Fact(run, Find(run, project.actorId).name .. "完成“" .. definition.name .. "”。", { project.actorId }, { projectId = project.id, reward = definition.reward })
end

local function EndDuty(run, contract, duty, failed, natural)
    duty.status = failed and "ended" or "completed"
    if duty.kind == "care" then
        local family = Family(run, contract.householdId)
        family.assets.money = family.assets.money + duty.money; family.assets.grain = family.assets.grain + duty.grain
        duty.money = 0; duty.grain = 0
        if failed and not natural then run.reputation = math.max(0, run.reputation - math.max(0, 4 - duty.penalties)); duty.penalties = 4 end
    end
    if duty.kind == "land" and duty.title == "restricted" then
        if failed then run.land = math.max(0, run.land - 1); Family(run, contract.householdId).assets.land = Family(run, contract.householdId).assets.land + 1; duty.title = "returned"
        else duty.title = "owned" end
    end
    if failed and not natural then
        if duty.kind == "study" then run.money = run.money - duty.rebate; run.reputation = math.max(0, run.reputation - 2) end
        if duty.kind == "land" then run.reputation = math.max(0, run.reputation - 4) end
    end
    Fact(run, "婚约“" .. duty.name .. "”" .. (failed and (natural and "因家人离世结束。" or "未能履约，约定款项与田契已结清。") or "履行完毕。"), { contract.memberId, contract.spouseId }, { contractId = contract.id, duty = duty.kind, natural = natural })
end

function Marriage.DutyReason(run, contractId, kind, memberId)
    local contract, member = Contract(run, contractId), Find(run, memberId)
    if not contract or not Home(member) or not State.IsAdult(member) then return false, "接手人需在家且成年。" end
    for _, duty in ipairs(contract.duties) do
        if duty.kind == kind and (duty.status == "active" or duty.status == "awaiting") then
            if kind ~= "land" then return false, "这项约定有指定对象，需由原定人履行。" end
            local original, spouse = Find(run, contract.memberId), Find(run, contract.spouseId)
            if original.alive or spouse.alive then return false, "守业仍由原夫妻共同负责。" end
            return true, ""
        end
    end
    return false, "约定已经结束。"
end

function Marriage.DutyAction(run, contractId, kind, action, memberId)
    if run.ending then return false, "本局已落笔。" end
    local contract = Contract(run, contractId)
    if not contract then return false, "婚约不存在。" end
    for _, duty in ipairs(contract.duties) do
        if duty.kind == kind and (duty.status == "active" or duty.status == "awaiting") then
            if action == "takeover" then
                local ok, reason = Marriage.DutyReason(run, contractId, kind, memberId)
                if not ok then return false, reason end
                duty.heirId = memberId; duty.status = "active"
                Fact(run, Find(run, memberId).name .. "接手亲家守业约定，保留原进度和期限。", { memberId }, { contractId = contractId })
            elseif action == "end" then
                local natural = not Find(run, contract.memberId).alive and not Find(run, contract.spouseId).alive
                EndDuty(run, contract, duty, true, natural)
            else return false, "约定处理方式无效。" end
            return true, "约定已按所选方式处理。"
        end
    end
    return false, "约定已经结束。"
end

function Marriage.MigrationConsequences(run, placeId)
    local result = { money = 0, lines = {}, duties = {} }
    for _, contract in ipairs(run.marriage.contracts) do
        if contract.placeId ~= placeId then
            for _, duty in ipairs(contract.duties) do
                if (duty.status == "active" or duty.status == "awaiting") and duty.kind ~= "care" then
                    local natural = duty.kind == "study" and not Find(run, duty.targetId).alive
                        or duty.kind == "land" and not Find(run, contract.memberId).alive and not Find(run, contract.spouseId).alive and not duty.heirId
                    local money = duty.kind == "study" and not natural and duty.rebate or 0
                    result.money = result.money + money
                    table.insert(result.lines, duty.name .. "：" .. (duty.kind == "land" and "归还1亩田" or ("返还减免" .. money .. "两")) .. (natural and "，自然结清。" or ("，声望减" .. (duty.kind == "land" and 4 or 2) .. "。")))
                    table.insert(result.duties, { contractId = contract.id, kind = duty.kind, natural = natural })
                end
            end
        end
    end
    return result
end

function Marriage.OnMigration(run, placeId)
    for _, item in ipairs(Marriage.MigrationConsequences(run, placeId).duties) do
        local contract = Contract(run, item.contractId)
        for _, duty in ipairs(contract.duties) do if duty.kind == item.kind then EndDuty(run, contract, duty, true, item.natural) end end
    end
end

function Marriage.Settle(run, rows)
    local year, result = run.yearIndex + 1, { money = 0, grain = 0, thrift = 0, growth = 0, sources = {} }
    local gains, moneyBuff = {}, {}
    local function Buff(targetId, stat, amount, source, consume)
        local member = Find(run, targetId)
        if not Home(member) or not Row(rows, targetId) or (member.stats[stat] or 0) >= 100 then return end
        local key = targetId .. ":" .. stat
        if not gains[key] or amount > gains[key].amount then gains[key] = { targetId = targetId, stat = stat, amount = amount, source = source, consume = consume } end
    end
    for _, contract in ipairs(run.marriage.contracts) do
        local aid = contract.aid
        if aid and aid.remaining > 0 and year <= aid.expires then
            local actor = Find(run, aid.targetId)
            local row = actor and Row(rows, actor.id)
            if not actor or not actor.alive then aid.remaining = 0
            elseif Home(actor) and row then
                if aid.kind == "grain" then
                    run.grain = run.grain + aid.amount; result.grain = result.grain + aid.amount; aid.remaining = aid.remaining - 1
                    table.insert(result.sources, { name = "亲家粮助", grain = aid.amount, memberId = actor.id })
                elseif aid.kind == "money" then
                    local key = actor.id
                    if not moneyBuff[key] or aid.amount > moneyBuff[key].amount then moneyBuff[key] = { amount = aid.amount, source = "亲家周转", consume = function() aid.remaining = aid.remaining - 1 end } end
                else
                    local jobs = { learn = { "study", "teach" }, skill = { "apprentice", "craft" }, medicine = { "medical", "doctor" }, martial = { "train", "guard" } }
                    if Has(jobs[aid.kind], row.jobId) then Buff(actor.id, aid.kind, aid.amount, "亲家传艺", function() aid.remaining = aid.remaining - 1 end) end
                end
            end
        end
        for _, duty in ipairs(contract.duties) do
            if duty.status == "awaiting" and year >= duty.deadline then EndDuty(run, contract, duty, true, true) end
            if duty.status == "active" then
                local partner, actor = Find(run, contract.spouseId), Find(run, contract.memberId)
                local forced = false
                for _, fact in ipairs(run.facts) do
                    if fact.kind == "migration" and fact.forced == true and fact.year == run.calendar and fact.placeId == run.placeId then forced = true; break end
                end
                if forced and duty.extensions < 2 then duty.deadline = duty.deadline + 1; duty.extensions = duty.extensions + 1 end
                if duty.kind == "care" then
                    local elder, carer = Find(run, duty.elderId), false
                    for _, row in ipairs(rows) do if row.executed and row.memberId ~= duty.elderId and row.jobId == "home" and State.IsAdult(Find(run, row.memberId)) then carer = true end end
                    if not elder.alive then EndDuty(run, contract, duty, false, true)
                    elseif Home(elder) and carer then
                        run.money = run.money + 2; run.grain = run.grain + 2; result.money = result.money + 2; result.grain = result.grain + 2
                        duty.money = duty.money - 2; duty.grain = duty.grain - 2; duty.progress = duty.progress + 1
                        if duty.progress >= duty.required then EndDuty(run, contract, duty, false) end
                    elseif not forced and duty.penalties < 4 then run.reputation = math.max(0, run.reputation - 2); duty.penalties = duty.penalties + 2 end
                elseif duty.kind == "study" then
                    local target = Find(run, duty.targetId)
                    if not target.alive then EndDuty(run, contract, duty, true, true)
                    elseif Home(target) and Row(rows, target.id) and target.jobId == duty.job and run.placeId == contract.placeId then duty.progress = duty.progress + 1 end
                elseif duty.kind == "land" then
                    local farmer = false; for _, row in ipairs(rows) do if row.executed and row.jobId == "farm" then farmer = true end end
                    if not actor.alive and not partner.alive and not Home(Find(run, duty.heirId)) then duty.status = "awaiting"
                    elseif farmer and run.placeId == contract.placeId then duty.progress = duty.progress + 1 end
                end
                if duty.status == "active" and duty.kind ~= "care" and duty.progress >= duty.required and (duty.kind ~= "land" or year - duty.started >= 5) then EndDuty(run, contract, duty, false) end
                if duty.status == "active" and (year >= duty.deadline or (duty.kind ~= "care" and run.placeId ~= contract.placeId and not forced)) then EndDuty(run, contract, duty, true) end
            end
        end
    end
    for _, project in ipairs(run.marriage.projects) do
        if project.status == "active" or project.status == "paused" then
            local actor, definition = Find(run, project.actorId), M.Projects[project.kind]
            local row = Row(rows, project.actorId)
            if not Home(actor) then project.status = "paused"; Slot(run, project.id, { project.actorId }, definition.name, "paused") end
            if project.status == "active" and row and row.jobId == definition.job then
                if project.kind ~= "officer" or actor.health >= 50 then
                    if not definition.stat then project.progress = project.progress + 1 end
                    if project.kind == "artisan" then project.unspent = math.max(0, project.unspent - 10) end
                    if project.kind == "merchant" then project.unspent = 0 end
                    if definition.stat then Buff(actor.id, definition.stat, definition.gain, definition.name, function()
                        project.progress = project.progress + 1
                        if project.progress >= (definition.charges or definition.work) then CompleteProject(run, project, year, result) end
                    end) end
                    if definition.money then
                        if not moneyBuff[actor.id] or definition.money >= moneyBuff[actor.id].amount then moneyBuff[actor.id] = { amount = definition.money, source = definition.name } end
                    end
                    if definition.reputation then run.reputation = run.reputation + definition.reputation end
                    local required = definition.charges or definition.work
                    if not definition.stat and project.progress >= required then CompleteProject(run, project, year, result) end
                end
            end
        end
    end
    local farming = false; for _, row in ipairs(rows) do if row.executed and row.jobId == "farm" then farming = true end end
    local dietUsed = false
    for _, tradition in ipairs(run.marriage.traditions) do
        local holder = Find(run, tradition.holderId)
        local row = holder and Row(rows, holder.id)
        if Home(holder) and row then
            if tradition.kind == "farming" and farming then
                local generation = tostring(Generation(holder))
                local source = tradition
                for _, item in ipairs(run.marriage.traditions) do if item.lineage == tradition.lineage then source = item; break end end
                local uses = source.generationUses[generation] or { used = 0 }
                local target = Find(run, uses.targetId)
                if not target then
                    for _, reader in ipairs(rows) do
                        local person = Find(run, reader.memberId)
                        if reader.executed and reader.jobId == "study" and Generation(person) == Generation(holder) then target = person; break end
                    end
                end
                if target and Row(rows, target.id) and target.jobId == "study" and uses.used < 3 then
                    Buff(target.id, "learn", 1, "耕读相济", function() uses.targetId = target.id; uses.used = uses.used + 1; source.generationUses[generation] = uses end)
                end
            elseif tradition.kind == "thrift" and row.jobId == "home" then result.thrift = 2
            elseif tradition.kind == "diet" and row.jobId == "home" and not dietUsed and run.grain >= 1 then
                local count = 0
                for _, resting in ipairs(rows) do
                    local person = Find(run, resting.memberId)
                    if resting.executed and resting.jobId == "rest" and person.health < 100 and count < 2 then person.health = math.min(100, person.health + 2); count = count + 1 end
                end
                if count > 0 then run.grain = run.grain - 1; result.grain = result.grain - 1; dietUsed = true; table.insert(result.sources, { name = "药膳家法", grain = -1, patients = count }) end
            end
        end
    end
    for _, object in ipairs(run.marriage.objects) do
        local holder = Find(run, object.holderId)
        if object.kind == "book" and object.charges > 0 and Home(holder) and Row(rows, holder.id) and holder.jobId == "study" then
            Buff(holder.id, "learn", 2, "亲家旧书", function() object.charges = object.charges - 1 end)
        end
    end
    for _, buff in pairs(gains) do
        local amount = Gain(Find(run, buff.targetId), buff.stat, buff.amount)
        if amount > 0 then
            if buff.consume then buff.consume() end
            result.growth = result.growth + amount
            table.insert(result.sources, { name = buff.source, memberId = buff.targetId, stat = buff.stat, growth = amount })
            local row = Row(rows, buff.targetId)
            row.marriageGrowth = (row.marriageGrowth or 0) + amount
            if row.growth and row.growth.stat == buff.stat then row.growth.amount = row.growth.amount + amount end
        end
    end
    for actorId, buff in pairs(moneyBuff) do
        run.money = run.money + buff.amount; result.money = result.money + buff.amount
        if buff.consume then buff.consume() end
        local row = Row(rows, actorId); row.money = row.money + buff.amount; row.marriageIncome = buff.amount
        table.insert(result.sources, { name = buff.source, memberId = actorId, money = buff.amount })
    end
    if run.marriage.workshopImproved and run.workshop then
        for _, row in ipairs(rows) do if row.executed and row.jobId == "craft" then run.money = run.money + 4; result.money = result.money + 4; table.insert(result.sources, { name = "旧图改坊", money = 4 }); break end end
    end
    for _, project in ipairs(run.marriage.projects) do
        if (project.status == "active" or project.status == "paused") and year >= project.deadline then
            project.status = "expired"; run.money = run.money + project.unspent; result.money = result.money + project.unspent; project.refunded = project.unspent; project.unspent = 0
            Slot(run, project.id, { project.actorId }, M.Projects[project.kind].name, "expired")
            Fact(run, "“" .. M.Projects[project.kind].name .. "”到期，退回未用款" .. project.refunded .. "两。", { project.actorId })
        end
    end
    for _, lesson in ipairs(run.marriage.lessons) do
        if lesson.status == "active" then
            local mentor, student = Find(run, lesson.mentorId), Find(run, lesson.studentId)
            local row = Row(rows, lesson.studentId)
            if not Home(mentor) or not Home(student) then lesson.status = "paused"; Slot(run, lesson.id, { lesson.mentorId }, "家法传习", "paused")
            elseif row and lesson.kind ~= "trust" then
                local jobs = ({ farming = { "study" }, diet = { "medical", "doctor", "home" }, thrift = { "home", "trade" } })[lesson.kind]
                if Has(jobs, row.jobId) then lesson.progress = lesson.progress + 1 end
            end
            if lesson.status == "active" and lesson.progress >= (lesson.kind == "farming" and 3 or 2) then
                local source = Marriage.Tradition(run, lesson.mentorId)
                if not Marriage.Tradition(run, lesson.studentId) then
                    table.insert(run.marriage.traditions, { id = lesson.id .. "-learned", kind = lesson.kind, holderId = lesson.studentId, lineage = lesson.lineage, generationUses = State.Copy(source.generationUses), completedProjects = {} })
                    Fact(run, student.name .. "学会“" .. M.Traits[lesson.kind].name .. "”，传承由实际经历确立。", { mentor.id, student.id })
                end
                lesson.status = "completed"; Slot(run, lesson.id, { lesson.mentorId }, "家法传习", "completed")
            end
        end
    end
    return result
end

function Marriage.ChildResidence(run, parent)
    local contract = parent.marriageId and Contract(run, parent.marriageId)
    return contract and contract.childHome or "home"
end

local function AddStory(run, contract, kind, title, detail, payload)
    local id = contract.id .. ":" .. kind
    if M.Find(run.marriage.stories, id) then return end
    table.insert(run.marriage.stories, { id = id, contractId = contract.id, kind = kind, title = title, detail = detail, payload = payload, status = "pending", year = run.yearIndex })
end

function Marriage.AfterYear(run)
    local world = run.marriage
    for _, member in ipairs(run.members) do
        if member.alive and not State.IsResident(member) and member.bornYearIndex ~= run.yearIndex then
            member.age = member.age + 1
            if member.age >= 70 and M.Hash(world.seed .. ":death:" .. member.id .. ":" .. run.yearIndex) % 1000 < (member.age - 67) * 8 then
                member.alive = false; member.ageAtDeath = member.age
                State.AddFact(run, "death", member.name .. "在外家离世，生平仍存家谱。", { member.id })
            end
        end
    end
    for _, project in ipairs(world.projects) do
        if project.status == "active" and not Home(Find(run, project.actorId)) then
            project.status = "paused"; Slot(run, project.id, { project.actorId }, M.Projects[project.kind].name, "paused")
        end
    end
    for _, lesson in ipairs(world.lessons) do
        if lesson.status == "active" and (not Home(Find(run, lesson.mentorId)) or not Home(Find(run, lesson.studentId))) then
            lesson.status = "paused"; Slot(run, lesson.id, { lesson.mentorId }, "家法传习", "paused")
        end
    end
    for _, family in ipairs(world.households) do
        local patron = family.patron
        local person = patron.memberId and Find(run, patron.memberId)
        if person then patron.age = person.age; patron.alive = person.alive
        elseif patron.alive then
            patron.age = patron.age + 1
            if patron.age >= 70 and M.Hash(world.seed .. ":patron:" .. family.id .. ":" .. run.yearIndex) % 1000 < (patron.age - 67) * 8 then patron.alive = false end
        end
        patron.active = patron.alive and patron.age < patron.retireAge
    end
    for _, candidate in ipairs(world.candidates) do
        if candidate.status == "available" then
            candidate.age = candidate.age + 1
            if candidate.age > 60 or M.Hash(world.seed .. ":leave:" .. candidate.id .. ":" .. run.yearIndex) % 100 < 12 then candidate.status = "departed" end
        end
    end
    local available = 0; for _, candidate in ipairs(world.candidates) do if candidate.status == "available" then available = available + 1 end end
    if available < 10 then M.GenerateHousehold(run) end
    for _, contract in ipairs(world.contracts) do
        local family = Family(run, contract.householdId)
        local patron, spouse, member = family.patron, Find(run, contract.spouseId), Find(run, contract.memberId)
        if not spouse.alive or not member.alive then contract.status = "widowed" end
        local roll = M.Hash(world.seed .. ":story:" .. contract.id .. ":" .. run.yearIndex) % 100
        if not patron.alive and not family.claimed.legacy and family.assets.book and (Home(spouse) or Home(member)) then
            AddStory(run, contract, "legacy", "亲家留下一匣旧书", "长辈离世后，家人来问这匣书由谁保管。接受后仍需实际读书，剩余用途会随物件传承。", { familyId = family.id })
        elseif family.assets.grain >= 3 and run.grain < 12 and roll < 40 then
            AddStory(run, contract, "grain", "亲家送来余粮", "亲家愿从现有存粮中分出3石，接下这份情分会留下往来记录。", { familyId = family.id, grain = 3 })
        elseif roll < 18 and contract.form ~= "in" and spouse.alive and member.alive then
            AddStory(run, contract, "reunion", "两家商议团聚", "亲家愿让夫妻在本家安居。需每位迁入者4两安置费，另付两家路费；孩子此后归本家。", { familyId = family.id })
        elseif roll < 22 and family.patron.role == "merchant" and not family.claimed.shop and family.assets.money >= 40 then
            AddStory(run, contract, "shop", "亲家商议交接铺面", "亲家愿出40两资助接铺，本家支付80两并安排实际行商，交接后获得商铺。", { familyId = family.id })
        end
    end
end

function Marriage.Archive(run)
    for _, project in ipairs(run.marriage.projects) do
        if project.status == "active" or project.status == "paused" then
            project.status = "archived"; Slot(run, project.id, { project.actorId }, M.Projects[project.kind].name, "archived")
        end
    end
    for _, lesson in ipairs(run.marriage.lessons) do
        if lesson.status == "active" or lesson.status == "paused" then
            lesson.status = "archived"; Slot(run, lesson.id, { lesson.mentorId }, "家法传习", "archived")
        end
    end
    for _, contract in ipairs(run.marriage.contracts) do
        for _, duty in ipairs(contract.duties) do if duty.status == "active" or duty.status == "awaiting" then duty.status = "archived" end end
    end
    for _, story in ipairs(run.marriage.stories) do if story.status == "pending" then story.status = "archived" end end
end

function Marriage.ResolveStory(run, storyId, accept, targetId)
    if run.ending then return false, "本局已落笔。" end
    local story = M.Find(run.marriage.stories, storyId)
    if not story or story.status ~= "pending" then return false, "这段往来已经处理。" end
    local contract = Contract(run, story.contractId)
    local family = Family(run, contract.householdId)
    if accept then
        if story.kind == "grain" then
            if family.assets.grain < 3 then return false, "亲家的余粮已有其他用途。" end
            family.assets.grain = family.assets.grain - 3; run.grain = run.grain + 3
        elseif story.kind == "legacy" then
            local target = Find(run, targetId)
            if not Home(target) or family.claimed.legacy or not family.assets.book then return false, "请选择在家保管人，且旧书仍在亲家。" end
            table.insert(run.marriage.objects, { id = family.id .. "-legacy", kind = "book", holderId = targetId, charges = 3, contractId = contract.id })
            family.assets.book = false; family.claimed.legacy = true
        elseif story.kind == "shop" then
            if run.shop or run.money < 80 or family.assets.money < 40 or family.claimed.shop then return false, "需无商铺、本家80两和亲家40两。" end
            local trader = false; for _, person in ipairs(run.members) do if Home(person) and person.jobId == "trade" and State.CanUseJob(person, "trade") then trader = true end end
            if not trader then return false, "需有符合条件的族人实际行商。" end
            run.money = run.money - 80; run.shop = true; family.assets.money = family.assets.money - 40; family.claimed.shop = true
            State.AddFact(run, "asset_purchase", "按亲家约定实际接下铺面，本家支付80两。", { contract.memberId, contract.spouseId }, { assetId = "shop", price = 80, contractId = contract.id })
        else
            local count = 0
            for _, id in ipairs({ contract.memberId, contract.spouseId }) do local person = Find(run, id); if not person.alive then return false, "夫妻已有一人离世。" end; if not State.IsResident(person) then count = count + 1 end end
            local cost = count * 4 + Fare(family.placeId, run.placeId)
            if run.money < cost then return false, "团聚安置需要" .. cost .. "两。" end
            run.money = run.money - cost
            for _, id in ipairs({ contract.memberId, contract.spouseId }) do local person = Find(run, id); person.residence = "home"; person.residencePlaceId = run.placeId end
            contract.childHome = "home"; contract.form = "in"
        end
    end
    story.status = accept and "accepted" or "declined"; story.resolvedYear = run.yearIndex
    Fact(run, story.title .. (accept and "，两家已照约办妥。" or "，家人婉言谢过。"), { contract.memberId, contract.spouseId }, { storyId = story.id })
    return true, "亲家往来已记入家史。"
end

return Marriage
