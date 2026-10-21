local Data = require "Jiaye.Data"
local R = {}

local WORK = { farm = true, craft = true, trade = true, teach = true, doctor = true, guard = true, official = true }
local USE = { craft = "skill", trade = "trade", teach = "learn", official = "learn", doctor = "medicine", guard = "martial" }
local STUDY = { craft = "apprentice", teach = "study", official = "study", doctor = "medical", guard = "train" }
local STAT_IDS = { "learn", "skill", "medicine", "trade", "martial" }
R.Stories = {
    ["relic.genealogy"] = "genealogy.compile_chronicle", ["relic.ruler"] = "ruler.upgrade_3",
    ["relic.letter"] = "letter.fulfil_promise", ["relic.plan"] = "plan.bridge",
    ["relic.jade"] = "jade.choose_final_form", ["relic.notes"] = "notes.upgrade_3",
    ["origin.seed_exchange"] = true, ["origin.workshop_repair"] = true, ["origin.old_accounts"] = true,
    ["origin.scroll_loan"] = true, ["origin.escort"] = true, ["origin.old_guest"] = true,
}

local function Count(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

local function Year(run, fact)
    return fact.yearIndex or math.max(0, (fact.year or run.openingSnapshot.calendar) - run.openingSnapshot.calendar)
end

local function Result(current, target, evidence)
    return { current = current, target = target, evidence = evidence or {} }
end

local function Proof(run, ids, members, values)
    local descriptions, names = {}, {}
    for _, id in ipairs(ids or {}) do
        for _, fact in ipairs(run.facts) do if fact.id == id then descriptions[#descriptions + 1] = fact.text; break end end
    end
    for _, id in ipairs(members or {}) do
        for _, member in ipairs(run.members) do if member.id == id then names[#names + 1] = member.name; break end end
    end
    return { runId = run.runId, family = run.openingSnapshot.family, worldId = run.worldId,
        yearIndex = run.yearIndex, calendar = run.calendar, sourceIds = ids or {}, memberIds = members or {}, values = values or {}, descriptions = descriptions, memberNames = names }
end

local function Streak(ledgers, predicate)
    local best, length, last = 0, 0, -1
    for _, ledger in ipairs(ledgers) do
        length = predicate(ledger) and (ledger.yearIndex == last + 1 and length + 1 or 1) or 0
        best, last = math.max(best, length), ledger.yearIndex
    end
    return best
end

local function After(history, job, year)
    local count = 0
    for _, row in ipairs(history) do if row.executed and row.jobId == job and row.year > year then count = count + 1 end end
    return count
end

local function Context(run)
    local c = { run = run, members = {}, ledgers = {}, facts = {}, actions = {}, joins = {}, born = {}, purchases = {}, upgrades = {}, migrations = {} }
    for _, member in ipairs(run.members) do
        c.members[member.id] = { member = member, baseline = run.achievementState.baselines[tostring(member.id)], history = {}, jobs = {}, growth = {}, uses = {}, minorYears = 0 }
    end
    local uniqueYears = {}
    for _, ledger in ipairs(run.annualLedgers) do
        assert(not uniqueYears[ledger.yearIndex], "年度成就依据出现重复年份。")
        uniqueYears[ledger.yearIndex] = true
        table.insert(c.ledgers, ledger)
    end
    table.sort(c.ledgers, function(a, b) return a.yearIndex < b.yearIndex end)
    for _, ledger in ipairs(c.ledgers) do
        local starts = {}
        for _, member in ipairs((ledger.yearStart or {}).members or {}) do starts[member.id] = member end
        for _, row in ipairs(ledger.members or {}) do
            local person = c.members[row.memberId]
            if person then
                local original = starts[row.memberId] or {}
                local history = { year = ledger.yearIndex, age = original.age, generation = original.kinGeneration or original.generation,
                    jobId = row.jobId, executed = row.executed == true, ledgerId = ledger.id,
                    placeId = (ledger.yearStart or {}).placeId, income = row.money - (row.relicIncome or 0) - (row.originIncome or 0) }
                table.insert(person.history, history)
                if original.age and original.age < Data.AgeRules.adult then person.minorYears = person.minorYears + 1 end
                if history.executed then
                    person.jobs[row.jobId] = person.jobs[row.jobId] or {}
                    table.insert(person.jobs[row.jobId], history)
                    if USE[row.jobId] then person.uses[USE[row.jobId]] = true end
                    local growth = row.growth or {}
                    if person.baseline and ledger.yearIndex > person.baseline.year and growth.stat and growth.stat ~= "health" and type(growth.amount) == "number" then
                        person.growth[growth.stat] = (person.growth[growth.stat] or 0) + growth.amount
                    end
                end
            end
        end
    end
    for index = #run.facts, 1, -1 do
        local fact = run.facts[index]
        table.insert(c.facts, fact)
        if fact.kind == "birth" then c.born[fact.memberIds[3]] = fact end
        if fact.kind == "adoption" then c.born[fact.memberIds[2]], c.joins[fact.memberIds[2]] = fact, fact end
        if fact.kind == "relic_branch_joined" then c.joins[fact.memberId] = fact end
        if fact.kind == "relic" and fact.action == "invite_branch" then c.joins[fact.memberIds[2]] = fact end
        if fact.kind == "marriage" and fact.joinedMemberId then c.joins[fact.joinedMemberId] = fact end
        if fact.kind == "asset_purchase" then table.insert(c.purchases, fact) end
        if fact.kind == "home_upgrade" then table.insert(c.upgrades, fact) end
        if fact.kind == "migration" then table.insert(c.migrations, fact) end
        if fact.actionId and (fact.kind == "relic_upgrade" or fact.kind == "relic_plan_acquired" or fact.kind == "relic_branch_joined"
            or fact.kind == "family_chronicle_compiled" or fact.kind == "relic_notes_acquired" or fact.kind == "relic_case"
            or fact.kind == "relic_apprenticeship" or fact.kind == "relic_promise_kept" or fact.kind == "relic_task_settled"
            or fact.outcome == "ruler_mark_verified" or fact.taskStatus == "settled") then c.actions[fact.actionId] = fact end
        if fact.kind == "relic_apprenticeship" or fact.kind == "relic_task_settled" or fact.kind == "relic_case" then
            for _, id in ipairs(fact.memberIds) do
                local person = c.members[id]
                if person and person.baseline and Year(run, fact) >= person.baseline.year then
                    local skill = fact.kind == "relic_apprenticeship" and (id == fact.masterId and fact.masterGain or fact.learnerGain) or fact.skillGain
                    person.growth.skill = (person.growth.skill or 0) + (skill or 0)
                    person.growth.medicine = (person.growth.medicine or 0) + (fact.medicineGain or 0)
                end
            end
        end
    end
    table.sort(c.migrations, function(a, b) return Year(run, a) < Year(run, b) end)
    return c
end

function R.StoryProgress(profile)
    local count, source = 0, {}
    for _, story in pairs(profile.achievementStories or {}) do count = count + 1; source = story end
    return Result(count, 1, source), Result(count, 5, source)
end

function R.Evaluate(profile, run)
    local results, stories = {}, {}
    local longFamilies, endingFamilies = {}, {}
    for id, family in pairs(profile.achievementFamilies or {}) do
        if family.years >= 10 then table.insert(longFamilies, id) end
        for endingId in pairs(family.endings) do table.insert(endingFamilies, { runId = id, endingId = endingId, family = family }) end
    end
    table.sort(longFamilies)
    local different, endingSource = false, {}
    for _, first in ipairs(endingFamilies) do
        endingSource = { runId = first.runId, family = first.family.family, worldId = first.family.worldId, yearIndex = first.family.years, calendar = first.family.calendar, endingId = first.endingId }
        for _, second in ipairs(endingFamilies) do
            if first.runId ~= second.runId and first.endingId ~= second.endingId then
                different = true; endingSource.familyIds = { first.runId, second.runId }
            end
        end
    end
    results[82] = Result(different and 2 or math.min(1, #endingFamilies), 2, endingSource)
    local longSource = longFamilies[1] and profile.achievementFamilies[longFamilies[1]] or {}
    results[83] = Result(#longFamilies, 2, { runId = longFamilies[1], family = longSource.family, worldId = longSource.worldId,
        yearIndex = longSource.years, calendar = longSource.calendar, familyIds = longFamilies })
    results[79], results[80] = R.StoryProgress(profile)
    if not run then return results, stories end
    local c = Context(run)
    local function Put(index, current, target, evidence)
        results[index] = Result(current, target, evidence or Proof(run, {}, {}, { current = current, target = target }))
    end
    local function Fact(index, predicate)
        for _, fact in ipairs(c.facts) do
            if predicate(fact) then Put(index, 1, 1, Proof(run, { fact.id }, fact.memberIds, { actionId = fact.actionId, outcome = fact.outcome, branch = fact.branch })); return end
        end
        Put(index, 0, 1)
    end
    local function Action(index, actionId)
        local fact = c.actions[actionId]
        Put(index, fact and 1 or 0, 1, fact and Proof(run, { fact.id }, fact.memberIds, { actionId = actionId, branch = fact.branch }) or nil)
    end
    Put(1, #c.ledgers, 1)
    Put(2, #c.ledgers, 20)
    local handed, retired, leaders = 0, 0, {}
    for _, term in ipairs(run.leaderTerms) do
        local years = 0
        for _, ledger in ipairs(c.ledgers) do
            if (ledger.yearStart or {}).leaderId == term.memberId and ledger.yearIndex > term.startYear
                and (not term.endYear or ledger.yearIndex <= term.endYear) then years = years + 1 end
        end
        if years >= 2 then leaders[term.memberId] = true end
        if term.realHandover and years >= 1 then handed = 1 end
        if term.endYear then
            local person = c.members[term.memberId]
            local homeYears = 0
            for _, row in ipairs(person and person.history or {}) do if row.year > term.endYear and row.executed then homeYears = homeYears + 1 end end
            retired = math.max(retired, homeYears)
        end
    end
    Put(3, handed, 1); Put(4, retired, 2); Put(5, Count(leaders), 3)
    local joined, grown = 0, 0
    for id, person in pairs(c.members) do
        local fact = c.joins[id]
        for _, row in ipairs(person.history) do if fact and row.year > Year(run, fact) then joined = 1 end end
        if person.member.age >= Data.AgeRules.adult then grown = math.max(grown, person.minorYears) end
    end
    Put(6, joined, 1); Put(7, grown, 5)
    local generations = 0
    if #c.ledgers >= 5 then
        for _, child in ipairs(run.members) do
            if child.alive then
                for _, parentId in ipairs(child.parents or {}) do
                    local parent = c.members[parentId] and c.members[parentId].member
                    for _, grandId in ipairs(parent and parent.parents or {}) do
                        local grand = c.members[grandId] and c.members[grandId].member
                        if parent.alive and grand and grand.alive and (c.born[child.id] or c.born[parentId] or c.born[grandId]) then generations = 3 end
                    end
                end
            end
        end
    end
    Put(8, generations, 3)
    local varied = 0
    for _, ledger in ipairs(c.ledgers) do
        local jobs = {}
        for _, person in pairs(c.members) do
            for index, row in ipairs(person.history) do
                local previous = person.history[index - 1]
                if row.year == ledger.yearIndex and row.executed and previous and previous.executed
                    and previous.year + 1 == row.year and previous.jobId == row.jobId then jobs[row.jobId] = true end
            end
        end
        varied = math.max(varied, Count(jobs))
    end
    Put(9, varied, 3)
    local shared = false
    for _, first in pairs(c.members) do
        for jobId in pairs(WORK) do
            local years = first.jobs[jobId] or {}
            if #years >= 3 then
                for _, second in pairs(c.members) do
                    local laterYears = 0
                    for _, row in ipairs(second.jobs[jobId] or {}) do
                        if row.generation and years[3].generation and row.generation > years[3].generation and row.year > years[3].year then laterYears = laterYears + 1 end
                    end
                    if laterYears >= 3 then shared = true end
                end
            end
        end
    end
    Put(10, shared and 1 or 0, 1)
    local learned, expert, changed, late, teacher, twoSkills, persistence, returned = 0, 0, 0, 0, 0, 0, 0, 0
    for _, person in pairs(c.members) do
        for jobId, trainingId in pairs(STUDY) do
            local training, work = person.jobs[trainingId] or {}, person.jobs[jobId] or {}
            if #training >= 2 and #work > 0 and work[1].year > training[2].year then learned = 1 end
        end
        local skillCount = 0
        for _, stat in ipairs(STAT_IDS) do
            local value = person.member.stats[stat] or 0
            local gain = person.baseline and value - (person.baseline.stats[stat] or 0) or 0
            if value >= 70 and gain >= 20 then expert = 1 end
            if value >= 50 and gain >= 15 and person.uses[stat] then skillCount = skillCount + 1 end
            if person.baseline and person.baseline.talent <= 2 then persistence = math.max(persistence, person.growth[stat] or 0) end
        end
        twoSkills = math.max(twoSkills, skillCount)
        for firstJob in pairs(WORK) do
            local firstYears = person.jobs[firstJob] or {}
            if #firstYears >= 2 then
                for secondJob in pairs(WORK) do if secondJob ~= firstJob and After(person.history, secondJob, firstYears[2].year) >= 2 then changed = 1 end end
            end
        end
        local reading = person.jobs.study or {}
        if run.worldId == "mortal" and #reading > 0 and reading[1].age and reading[1].age >= 40 then late = math.max(late, #reading) end
        if #reading >= 2 then teacher = math.max(teacher, After(person.history, "teach", reading[2].year)) end
        for _, rest in ipairs(person.jobs.rest or {}) do
            for jobId, years in pairs(person.jobs) do
                if WORK[jobId] then
                    local before, after = 0, 0
                    for _, row in ipairs(years) do if row.year < rest.year then before = before + 1 elseif row.year > rest.year then after = after + 1 end end
                    if before >= 2 and after >= 1 then returned = 1 end
                end
            end
        end
    end
    Put(11, learned, 1); Put(12, expert, 1); Put(13, changed, 1); Put(14, late, 3); Put(15, teacher, 2)
    Put(16, twoSkills, 2); Put(17, persistence, 30); Put(19, returned, 1)
    Fact(18, function(f) return f.kind == "exam" and f.passed == true end)
    Put(20, Streak(c.ledgers, function(l) return l.foodSatisfied == true end), 3)
    Put(21, Streak(c.ledgers, function(l) return l.normalIncome ~= nil and l.trainingRequired ~= nil and l.training == l.trainingRequired
        and l.moneySatisfied == true and l.foodSatisfied == true and l.normalIncome >= l.livingExpense + l.foodCost + l.trainingRequired end), 3)
    local harvest, business, home, both = 0, 0, 0, 0
    for _, ledger in ipairs(c.ledgers) do
        local start = ledger.yearStart or {}
        for _, fact in ipairs(c.purchases) do
            if fact.assetId == "land" and ledger.yearIndex > Year(run, fact) and (ledger.landGrain or 0) > 0 then harvest = 1 end
        end
        if ledger.workshopOperated and ledger.shopOperated then both = both + 1 end
        for _, fact in ipairs(c.upgrades) do if ledger.yearIndex > Year(run, fact) and start.homeId == fact.toHomeId then home = 1 end end
    end
    for _, fact in ipairs(c.purchases) do
        local operated = 0
        for _, ledger in ipairs(c.ledgers) do
            if ledger.yearIndex > Year(run, fact) and (fact.assetId == "workshop" and ledger.workshopOperated or fact.assetId == "shop" and ledger.shopOperated) then operated = operated + 1 end
        end
        business = math.max(business, operated)
    end
    Put(22, harvest, 1); Put(23, business, 2); Put(24, home, 1); Put(26, both, 2)
    Put(25, Streak(c.ledgers, function(l)
        local jobs, members = {}, {}
        for _, row in ipairs(l.members or {}) do
            if row.executed and WORK[row.jobId] and row.money - (row.relicIncome or 0) - (row.originIncome or 0) > 0 then jobs[row.jobId], members[row.memberId] = true, true end
        end
        return Count(jobs) >= 2 and Count(members) >= 2
    end), 3)
    Fact(27, function(f) return f.kind == "commission_settled" and f.accepted and f.received == f.receivable and f.received > 0 end)
    local migrated, settled = 0, 0
    for index, migration in ipairs(c.migrations) do
        local nextMove = c.migrations[index + 1]
        local length, previous = 0, -1
        for _, ledger in ipairs(c.ledgers) do
            if ledger.yearIndex > Year(run, migration) and (not nextMove or ledger.yearIndex <= Year(run, nextMove))
                and (ledger.yearStart or {}).placeId == migration.placeId then
                migrated = 1
                length = ledger.moneySatisfied and ledger.foodSatisfied and (previous + 1 == ledger.yearIndex and length + 1 or 1) or 0
                settled, previous = math.max(settled, length), ledger.yearIndex
            end
        end
    end
    Put(28, migrated, 1); Put(29, settled, 3)
    Fact(30, function(f) return f.kind == "contact_exchange" and f.contactId and f.sourcePlaceId and f.sourcePlaceId ~= f.placeId and f.migrationCount > 0 end)
    Fact(31, function(f) return f.kind == "commission_settled" and f.received == f.receivable and f.received > 0 and f.buyerId == f.acceptedBuyerId
        and f.migrationCount and f.acceptedMigrationCount and f.migrationCount > f.acceptedMigrationCount end)
    Fact(32, function(f) return f.kind == "loan_returned" and f.approved == true and f.itemId == f.returnedItemId and f.recipientId == f.agreedRecipientId and f.closed == true end)
    local origin = run.originOpportunity
    if origin then
        local status = origin.archivedStatus or origin.status
        local transactionKinds = {}
        for _, entry in ipairs(run.originTransactions or {}) do transactionKinds[entry.category] = (transactionKinds[entry.category] or 0) + math.max(0, entry.money) + math.max(0, entry.grain) end
        Put(36, origin.sourceOriginId == "plain" and status == "settled" and (transactionKinds.event_grain_in or 0) >= 8 and 1 or 0, 1)
        Put(37, origin.sourceOriginId == "artisan" and status == "settled" and (transactionKinds.event_wage or 0) > 0 and 1 or 0, 1)
        Put(38, origin.sourceOriginId == "merchant" and (transactionKinds.old_debt_recovery or 0) >= 12 and 1 or 0, 1)
        Fact(39, function(f) return f.kind == "loan_returned" and f.effectiveYears and f.effectiveYears >= 1 and f.depositSettled == true end)
        Put(40, origin.sourceOriginId == "military" and status == "settled" and (transactionKinds.event_wage or 0) > 0 and 1 or 0, 1)
        Fact(41, function(f) return f.kind == "origin" and f.outcome == "referral_applied" and (f.actualLearn > 0 or f.actualMoney > 0) end)
    end
    Fact(42, function(f) return f.kind == "relic_upgrade" end)
    local inherited, succeeded = 0, 0
    for _, first in ipairs(run.relicUseFacts or {}) do
        for _, second in ipairs(run.relicUseFacts or {}) do
            if first.instanceId == second.instanceId and first.memberId ~= second.memberId and first.generation < second.generation and first.runYear < second.runYear then
                for _, fact in ipairs(c.facts) do
                    if fact.kind == "relic_handover" and fact.action == "assign_user" and fact.relicInstanceId == first.instanceId and fact.toMemberId == second.memberId
                        and Year(run, fact) >= first.runYear and Year(run, fact) < second.runYear then inherited = 1 end
                end
            end
        end
    end
    for _, task in ipairs(run.relicTasks or {}) do
        if task.status == "settled" then
            for _, handover in ipairs(task.handoverHistory or {}) do
                if handover.completedWorkYears > 0 and handover.completedWorkYears < task.totalWorkYears and handover.fromMemberId ~= handover.toMemberId then
                    for _, work in ipairs(task.workFacts or {}) do if work.executorId == handover.toMemberId and work.runYear > handover.yearIndex then succeeded = 1 end end
                end
            end
        end
    end
    Put(43, inherited, 1); Put(44, succeeded, 1)
    local actions = {
        [45] = "ruler.trace_mark", [46] = "ruler.copy_plan", [47] = "ruler.upgrade_3", [48] = "ruler.teach_successor",
        [49] = "genealogy.bind_verified_pages", [50] = "genealogy.invite_branch", [51] = "genealogy.upgrade_3", [52] = "genealogy.compile_chronicle",
        [53] = "letter.confirm_delivery", [54] = "letter.fulfil_promise", [55] = "plan.small_repair", [56] = "plan.upgrade_2",
        [57] = "plan.upgrade_3", [58] = "plan.bridge", [59] = "jade.verify_origin", [60] = "jade.choose_final_form",
        [61] = "notes.accept_old_cases", [62] = "notes.record_case", [63] = "notes.upgrade_2", [64] = "notes.upgrade_3",
    }
    for index, actionId in pairs(actions) do Action(index, actionId) end
    local decisions = {}
    for _, fact in ipairs(c.facts) do
        if fact.storyId and fact.storyNodeId and fact.isDecision and R.Stories[fact.storyId] then
            decisions[fact.storyId] = decisions[fact.storyId] or {}
            decisions[fact.storyId][fact.storyNodeId] = fact.id
        end
    end
    for id, nodes in pairs(decisions) do
        local closing = R.Stories[id]
        local closed = type(closing) == "string" and c.actions[closing] ~= nil
        if origin and id == origin.id then
            local status = origin.archivedStatus or origin.status
            closed = status == "settled" or status == "returned"
            if origin.sourceOriginId == "gentry" then closed = results[41] and results[41].current == 1 end
        end
        if closed and Count(nodes) >= 2 then
            local nodeIds, factIds = {}, {}
            for nodeId, factId in pairs(nodes) do table.insert(nodeIds, nodeId); table.insert(factIds, factId) end
            local record = Proof(run, factIds)
            record.nodes = nodeIds
            table.sort(record.nodes)
            stories[id] = record
        end
    end
    Put(81, run.ending and run.ending.type == "development" and not run.ending.automatic and 1 or 0, 1)
    return results, stories
end

return R
