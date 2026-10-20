local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Economy = require "Jiaye.Economy"
local Marriage = require "Jiaye.Marriage"
local Opening = require "Jiaye.Opening"
local cjson = require "cjson"

local Verify = {}
local M = Marriage.Rules
local function Equal(left, right) assert(Opening.Equal(left, right), "只读或拒绝操作改变了状态") end

local function New(seed, modern)
    local profile, draft = State.NewProfile(), State.NewDraft()
    draft.rngSeed = seed
    if modern then
        draft.rulesVersion = 2; draft.relicRulesVersion = "1.2"; draft.originRulesVersion = require("Jiaye.OriginState").VERSION
        draft.selectedRelicIds = nil; draft.selectedRelicFormIds = {}; draft.relicUsers = {}
        draft.backgroundId = "artisan"; draft.backgroundDefinition = nil
        for _, item in ipairs(require("Jiaye.Data").Backgrounds) do if item.originId == "artisan" then draft.backgroundId = item.id end end
    end
    local run, issues = State.NewRun(draft, profile)
    assert(run, issues and table.concat(issues, "；"))
    assert(Simulation.SetJob(run, 1, "trade"))
    assert(Simulation.SetJob(run, 3, "trade"))
    assert(Simulation.SetJob(run, 4, "rest"))
    assert(Simulation.SetBirthPlan(run, 1, false))
    assert(Simulation.SetBirthPlan(run, 2, false))
    return run, profile, draft
end

local function Year(run, profile)
    for _, event in ipairs(Simulation.PendingEvents(run)) do
        local choices = require("Jiaye.Data").EventChoices[event.type]
        assert(choices, "待决事件缺少操作")
        local resolved = false
        for _, choice in ipairs(choices) do
            if choice.allowed ~= false then
                local ok = Simulation.ResolveEvent(run, event.instanceId, choice.id, profile)
                if ok then resolved = true; break end
            end
        end
        assert(resolved, "待决事件未能处理")
    end
    local before = State.Copy(run)
    local prediction = Economy.Preview(run)
    Equal(before, run)
    assert(Simulation.AdvanceYear(run, profile))
    assert(run.lastLedger.money == prediction.money and run.lastLedger.grain == prediction.grain, "预估与实际年度账目不一致")
    return run.lastLedger
end

local function Offer(run, form, dutyKind, role, filter, memberId)
    memberId = memberId or 3
    for _, candidate in ipairs(Marriage.Candidates(run, memberId)) do
        local family = M.Find(run.marriage.households, candidate.householdId)
        if (not role or (family.patron.role == role and family.patron.active)) and (not filter or filter(family, candidate, run)) then
            for _, offer in ipairs(Marriage.Offers(run, candidate.id)) do
                if not dutyKind or (offer.duties[1] and offer.duties[1].kind == dutyKind) then
                    for _, allowed in ipairs(offer.forms) do
                        if allowed == form then
                            local input = { candidateId = candidate.id, offerId = offer.id, form = form, weddingId = "simple", childHome = "home" }
                            local quote = Marriage.Quote(run, memberId, input)
                            if quote and quote.affordable then return input, quote end
                        end
                    end
                end
            end
        end
    end
end

local function Search(form, dutyKind, role, modern, prepare, filter)
    for seed = 1, 1000 do
        local run, profile, draft = New(seed, modern)
        if prepare then prepare(run, profile) end
        local input, quote = Offer(run, form, dutyKind, role, filter)
        if input then return run, profile, draft, input, quote end
    end
    error("没有找到真实生成的婚约：" .. tostring(form) .. "/" .. tostring(dutyKind) .. "/" .. tostring(role))
end

function Verify.Run()
    local report = { forms = {}, responsibilities = {}, projects = {}, traditions = {}, seeds = 30 }
    for seed = 1, report.seeds do
        local run = New(seed)
        local before = State.Copy(run)
        Marriage.Candidates(run, 3); Marriage.Candidates(run, 3); Economy.Preview(run)
        Equal(before, run)
        local second = New(seed)
        Equal(run.marriage, second.marriage)
        for _, candidate in ipairs(run.marriage.candidates) do assert(candidate.age >= 18) end
        assert(not Marriage.Reason(run, 4)); assert(not Marriage.Marry(run, 4, {})); Equal(before, run)
        local input = Offer(run, "in")
        if input then
            local poor = State.Copy(run); poor.money = 0
            local original = State.Copy(poor); assert(not Marriage.Marry(poor, 3, input)); Equal(original, poor)
        end
    end
    for _, form in ipairs({ "in", "out", "dual" }) do
        local run, profile, draft, input, quote = Search(form, nil, nil, true)
        local beforeFood = Economy.StandardAnnualFoodNeed(run)
        assert(Marriage.Marry(run, 3, input)); assert(run.money == quote.money and run.grain == quote.grain)
        local spouse = State.FindMember(run.members, run.members[3].spouseId)
        assert(spouse.spouseId == 3 and spouse.age >= 18)
        assert(Economy.StandardAnnualFoodNeed(run) == beforeFood + quote.incoming * 2 - quote.outgoing * 2)
        local before = State.Copy(run); assert(not Marriage.Marry(run, 3, input)); Equal(before, run)
        local ledger = Year(run, profile)
        local ok, message = State.Save(profile, draft, run); assert(ok, message)
        local loaded = assert(State.Load()); Equal(run.marriage, loaded.run.marriage)
        assert(State.ValidateSavePayload(loaded))
        local continued = State.Copy(run)
        Year(continued, State.Copy(profile)); Year(loaded.run, loaded.profile)
        Equal(continued.marriage, loaded.run.marriage)
        report.forms[form] = { money = run.money, grain = run.grain, residentFood = ledger.foodNeed, contracts = #run.marriage.contracts }
    end
    for _, kind in ipairs({ "study", "care", "land" }) do
        local run, profile, draft, input = Search("in", kind)
        assert(Marriage.Marry(run, 3, input))
        local contract = run.marriage.contracts[1]
        local duty = contract.duties[1]
        if kind == "study" then assert(Simulation.SetJob(run, duty.targetId, duty.job)) end
        if kind == "care" then assert(Simulation.SetJob(run, 3, "home")) end
        for _ = 1, duty.required do Year(run, profile) end
        assert(duty.status == "completed", kind .. "责任未按实际行动完成")
        if kind == "land" then assert(duty.title == "owned") end
        report.responsibilities[kind] = { progress = duty.progress, status = duty.status }
        assert(State.ValidateSavePayload({ profile = profile, draft = draft, run = run, saveSchemaVersion = 2 }))
    end
    for _, kind in ipairs({ "tutor", "official", "merchant", "doctor", "officer", "artisan", "clan" }) do
        local definition = M.Projects[kind]
        local run, profile, draft, input = Search("in", nil, kind, true, function(current, collection)
            local actor = current.members[1]
            if kind == "officer" then
                assert(Simulation.SetJob(current, actor.id, "train"))
                while actor.stats.martial < 35 do Year(current, collection) end
            elseif kind == "official" then
                assert(Simulation.SetJob(current, actor.id, "study"))
                while not actor.examPassed do
                    if current.money >= 10 then assert(Simulation.TakeExam(current, actor.id)) end
                    if not actor.examPassed then Year(current, collection) end
                end
            end
            if kind == "artisan" then
                while current.money < 160 + definition.fee do Year(current, collection) end
                assert(Simulation.BuyAsset(current, "workshop"))
            end
        end)
        assert(Marriage.Marry(run, 3, input))
        local actor = run.members[1]
        if actor.jobId ~= definition.job then assert(Simulation.SetJob(run, actor.id, definition.job)) end
        while run.money < definition.fee do Year(run, profile) end
        local ok, reason = Marriage.StartProject(run, run.marriage.contracts[1].id, kind, actor.id)
        assert(ok, kind .. ":" .. tostring(reason))
        local project = run.marriage.projects[1]
        assert(Marriage.Busy(run, actor.id))
        local occupied = State.Copy(run)
        assert(not require("Jiaye.RelicSystem").RegisterExternalProject(run, "overlap-probe", { actor.id }, {}, { name = "占用验证" }))
        Equal(occupied, run)
        assert(Marriage.ProjectAction(run, project.id, "pause")); assert(not Marriage.Busy(run, actor.id))
        assert(Marriage.ProjectAction(run, project.id, "resume"))
        for _ = 1, definition.charges or definition.work do Year(run, profile) end
        assert(project.status == "completed", kind .. "事务未完成")
        assert(not Marriage.Busy(run, actor.id))
        if kind == "tutor" then assert(Marriage.ExamBonus(run, actor.id) == 0.08) end
        if kind == "artisan" then assert(run.marriage.workshopImproved) end
        report.projects[kind] = { status = project.status, progress = project.progress }
        local okSave, message = State.Save(profile, draft, run); assert(okSave, message)
    end
    for _, kind in ipairs({ "farming", "diet", "thrift", "trust" }) do
        local run, profile, draft, input = Search("in", nil, kind == "trust" and "merchant" or nil, true, function(current, collection)
            if kind == "trust" then while not State.IsAdult(current.members[4]) do Year(current, collection) end end
        end, function(family, candidate, current)
            return family.traitId == kind and family.patron.role ~= "artisan" and (kind ~= "trust" or (family.patron.age < 50 and Offer(current, "in", nil, "tutor", nil, 4)))
        end)
        assert(Marriage.Marry(run, 3, input))
        local mentorId = run.members[3].spouseId
        local studentId = kind == "farming" and 4 or 3
        if kind == "farming" then assert(Simulation.SetJob(run, 4, "study"))
        elseif kind == "diet" then
            assert(Simulation.SetJob(run, 3, "medical"))
            while run.members[3].stats.medicine < 25 do Year(run, profile) end
        elseif kind == "thrift" then
            while run.members[3].stats.trade < 25 do Year(run, profile) end
            assert(Simulation.SetJob(run, 3, "home"))
        else
            local second
            second = Offer(run, "in", nil, "tutor", nil, 4)
            assert(second, "没有遇到第二家真实生成的塾师婚约")
            assert(Marriage.Marry(run, 4, second))
        end
        assert(Marriage.Teach(run, mentorId, studentId))
        assert(Marriage.Busy(run, mentorId))
        if kind == "trust" then
            local firstContract = run.marriage.contracts[1]
            local ok, message = Marriage.StartProject(run, firstContract.id, "merchant", 3); assert(ok, message)
            Year(run, profile)
            assert(Simulation.SetJob(run, 3, "study"))
            assert(Marriage.StartProject(run, run.marriage.contracts[2].id, "tutor", 3))
            for _ = 1, 3 do Year(run, profile) end
        else for _ = 1, kind == "farming" and 3 or 2 do Year(run, profile) end end
        assert(Marriage.Tradition(run, studentId), kind .. "家法未能完成实际传习")
        if kind == "farming" then
            local inherited = Year(run, profile)
            for _, source in ipairs(inherited.marriage.sources) do assert(source.name ~= "耕读相济", "同代传习重置了耕读名额") end
        end
        assert(not Marriage.Busy(run, mentorId))
        report.traditions[kind] = { studentId = studentId, progress = run.marriage.lessons[1].progress }
        local ok, message = State.Save(profile, draft, run); assert(ok, message)
        Equal(run.marriage, assert(State.Load()).run.marriage)
    end
    local run, profile, draft, input = Search("in", nil, "merchant", true)
    assert(Marriage.Marry(run, 3, input))
    assert(Marriage.StartProject(run, run.marriage.contracts[1].id, "merchant", 1))
    local money = run.money
    assert(Marriage.ProjectAction(run, run.marriage.projects[1].id, "cancel"))
    assert(run.money == money + 12, "未动用商单本金未退回")
    local before = State.Copy(run); assert(not Marriage.ProjectAction(run, run.marriage.projects[1].id, "cancel")); Equal(before, run)
    local old = { profile = profile, draft = draft, run = State.Copy(run), saveSchemaVersion = 2 }
    old.run.marriage = nil
    for _, member in ipairs(old.run.members) do member.marriageId = nil end
    local migrated, message = State.PreflightImport(cjson.encode(old)); assert(migrated, message)
    assert(State.ValidateSavePayload(migrated))
    report.refundAndMigration = true
    for _, kind in ipairs({ "study", "land" }) do
        local moving, collection, _, choice = Search("in", kind, nil, true)
        assert(Marriage.Marry(moving, 3, choice))
        local duty = moving.marriage.contracts[1].duties[1]
        local quote = assert(Simulation.MigrationQuote(moving, "mountain"))
        local money, land, reputation = moving.money, moving.land, moving.reputation
        assert(Simulation.MoveFamily(moving, "mountain"))
        assert(duty.status == "ended" and moving.money == money - quote.totalCost)
        assert(moving.land == land - (kind == "land" and 1 or 0))
        assert(moving.reputation == math.max(0, reputation - (kind == "land" and 4 or 2)))
        Year(moving, collection)
        assert(duty.status == "ended", "婚约结清后再次执行责任")
    end
    local storyRun, storyProfile, storyDraft, storyInput = Search("out", nil, nil, true)
    assert(Marriage.Marry(storyRun, 3, storyInput))
    local pending
    for _ = 1, 12 do
        Year(storyRun, storyProfile)
        for _, story in ipairs(storyRun.marriage.stories) do if story.status == "pending" then pending = story; break end end
        if pending then break end
    end
    assert(pending, "年度处境尚未触发亲家往来")
    local accepted, reason = Marriage.ResolveStory(storyRun, pending.id, true, 1); assert(accepted, reason)
    local beforeStory = State.Copy(storyRun)
    assert(not Marriage.ResolveStory(storyRun, pending.id, true, 1)); Equal(beforeStory, storyRun)
    local saved, saveReason = State.Save(storyProfile, storyDraft, storyRun); assert(saved, saveReason)
    Equal(storyRun.marriage, assert(State.Load()).run.marriage)
    report.story = pending.kind
    print("PROCEDURAL_MARRIAGE_PASS " .. cjson.encode(report))
    return report
end

return Verify
