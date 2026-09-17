-- T07 验证七件信物的实例、执行人、保管人、故事阶段和跨局资格；不替代引擎绘制或真机输入。
local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"

local function findEvent(run, eventType, relicId)
    for _, event in ipairs(Simulation.PendingEvents(run)) do
        if event.type == eventType and (not relicId or event.relicInstanceId == relicId) then return event end
    end
end

local function find(root, value)
    if type(root.text) == "string" and root.text:find(value, 1, true) then return root end
    for _, child in ipairs(root.children or {}) do
        local result = find(child, value)
        if result then return result end
    end
end

local function hasFact(run, relicId, action)
    for _, fact in ipairs(run.facts or {}) do
        if fact.kind == "relic" and fact.relicInstanceId == relicId and (not action or fact.action == action) then return true end
    end
    return false
end

local function fresh()
    local profile, draft = State.NewProfile(), State.NewDraft()
    local run = assert(State.NewRun(draft, profile))
    run.money = 300
    for _, member in ipairs(run.members) do member.age = math.max(30, member.age); member.birthPlan = false; member.spouseId = nil end
    return run, profile, draft
end

local function addRelic(run, id, source)
    local instance = { instanceId = "test-" .. id, definitionId = id, status = "held", stage = "idle", source = source or "验收夹具", custodianId = 1, executorId = nil, rewardState = "none" }
    table.insert(run.relicInstances, instance)
    return instance
end

local function settleBasic(id, route, unlock)
    local run, profile = fresh()
    local instance = id == "ruler" and run.relicInstances[1] or addRelic(run, id)
    assert(Simulation.AssignRelicExecutor(run, instance.instanceId, 2))
    local before = run.money
    assert(Simulation.StartRelicInvestigation(run, instance.instanceId, route))
    assert(instance.executorId == 2 and instance.status == "investigating" and run.money < before and hasFact(run, instance.instanceId, "investigate"), id .. "没有记录执行人、成本和调查")
    local years = route == "slow" and 2 or 1
    for _ = 1, years do assert(Simulation.AdvanceYear(run, profile)) end
    local event = assert(findEvent(run, "relic_resolution", instance.instanceId), id .. "没有在到期后给出自己的后续")
    assert(Simulation.ResolveEvent(run, event.instanceId, "restore", profile))
    assert(profile.unlockedRelicIds[unlock] and instance.rewardState == "granted" and hasFact(run, instance.instanceId, "restore"), id .. "没有把本局结果与下局资格分开保存")
    assert(not Simulation.ResolveEvent(run, event.instanceId, "restore", profile) and not Simulation.StartRelicInvestigation(run, instance.instanceId, route), id .. "重复提交仍可重复发奖或收费")
    return run, profile, instance
end

local function run()
    local paused, pausedProfile = fresh()
    local ruler = paused.relicInstances[1]
    assert(Simulation.AssignRelicExecutor(paused, ruler.instanceId, 1) and Simulation.StartRelicInvestigation(paused, ruler.instanceId, "fast"))
    local paid = paused.money
    assert(Simulation.PauseRelicInvestigation(paused, ruler.instanceId) and ruler.status == "held" and ruler.stage == "paused" and ruler.dueYear == nil)
    assert(Simulation.AdvanceYear(paused, pausedProfile) and not findEvent(paused, "relic_resolution", ruler.instanceId) and paused.money ~= paid, "暂缓调查仍被当作到期结算")
    assert(Simulation.ResumeRelicInvestigation(paused, ruler.instanceId) and ruler.status == "investigating")
    assert(Simulation.AdvanceYear(paused, pausedProfile))
    local rulerEvent = assert(findEvent(paused, "relic_resolution", ruler.instanceId))
    assert(Simulation.ResolveEvent(paused, rulerEvent.instanceId, "restore", pausedProfile) and pausedProfile.unlockedRelicIds.plan and ruler.rewardState == "granted", "老木尺没有完成暂停后恢复、修复和营造图资格闭环")

    local bookRun, bookProfile, book = settleBasic("book", "slow", "newbook")
    local letterRun, letterProfile, letter = settleBasic("letter", "fast", "jade")
    assert(book.source == "验收夹具" and letter.source == "验收夹具" and book.executorId == 2 and letter.executorId == 2, "旧谱、家书没有保留各自来源和执行人")

    local planRun, planProfile = fresh()
    local plan = addRelic(planRun, "plan", "修复老木尺")
    planRun.yearIndex = 3
    assert(Simulation.AdvanceYear(planRun, planProfile))
    local planEvent = assert(findEvent(planRun, "plan_work", plan.instanceId), "营造图没有把修缮活绑定到物件实例")
    local planMoney = planRun.money
    assert(Simulation.ResolveEvent(planRun, planEvent.instanceId, "accept", planProfile))
    assert(plan.executorId == 1 and plan.stage == "work_completed" and planRun.money == planMoney + 18 and hasFact(planRun, plan.instanceId, "plan_work"), "营造图没有记录实际匠作、收益和故事阶段")

    local branchRun = fresh()
    local newbook = addRelic(branchRun, "newbook", "重修旧族谱")
    local count = #branchRun.members
    assert(Simulation.AssignRelicExecutor(branchRun, newbook.instanceId, 2) and Simulation.InviteBranch(branchRun, newbook.instanceId))
    assert(#branchRun.members == count + 1 and hasFact(branchRun, newbook.instanceId, "invite_branch"), "补完族谱没有记录实际寻亲人与旁支")

    local jadeRun, jadeProfile = fresh()
    local jade = addRelic(jadeRun, "jade", "完成一封旧约")
    assert(Simulation.AssignRelicExecutor(jadeRun, jade.instanceId, 2) and Simulation.StartJadeSearch(jadeRun, jade.instanceId))
    local jadeEvent = assert(findEvent(jadeRun, "jade_search", jade.instanceId))
    assert(Simulation.ResolveEvent(jadeRun, jadeEvent.instanceId, "search", jadeProfile))
    assert(jadeRun.flags.jadeReunited and jade.stage == "reunited" and hasFact(jadeRun, jade.instanceId, "jade_reunion"), "玉佩没有记录查访人和重逢结果")

    local notesRun, notesProfile = fresh()
    local doctor = notesRun.members[3]
    doctor.jobYears.doctor, doctor.stats.medicine = 4, 60
    assert(Simulation.AdvanceYear(notesRun, notesProfile))
    local offer = assert(findEvent(notesRun, "medical_find"))
    assert(Simulation.ResolveEvent(notesRun, offer.instanceId, "accept", notesProfile))
    local notes = nil; for _, instance in ipairs(notesRun.relicInstances) do if instance.definitionId == "notes" then notes = instance end end
    local notesEvent = assert(notes and findEvent(notesRun, "notes_choice", notes.instanceId))
    assert(Simulation.ResolveEvent(notesRun, notesEvent.instanceId, "print", notesProfile))
    assert(notesProfile.unlockedRelicIds.notes and notes.stage == "printed" and hasFact(notesRun, notes.instanceId, "notes_print"), "医案没有按实际行医取得并记录刊印结果")

    local failedRun, failedProfile = fresh()
    local failed = failedRun.relicInstances[1]
    assert(Simulation.AssignRelicExecutor(failedRun, failed.instanceId, 1) and Simulation.StartRelicInvestigation(failedRun, failed.instanceId, "fast"))
    failedRun.members[1].alive = false
    assert(Simulation.AdvanceYear(failedRun, failedProfile) and failed.stage == "awaiting_executor" and failed.status == "held", "执行人离世没有停止等待并要求重新托付")
    assert(Simulation.AssignRelicExecutor(failedRun, failed.instanceId, 2) and Simulation.ResumeRelicInvestigation(failedRun, failed.instanceId), "执行人离世后不能重新指定并恢复")

    local interruptedRun, interruptedProfile = fresh()
    local interrupted = addRelic(interruptedRun, "jade", "完成一封旧约")
    assert(Simulation.AssignRelicExecutor(interruptedRun, interrupted.instanceId, 1) and Simulation.StartJadeSearch(interruptedRun, interrupted.instanceId))
    local interruptedEvent = assert(findEvent(interruptedRun, "jade_search", interrupted.instanceId))
    interruptedRun.members[1].alive = false
    assert(not Simulation.ResolveEvent(interruptedRun, interruptedEvent.instanceId, "search", interruptedProfile) and interrupted.stage == "awaiting_executor", "待决玉佩事件在执行人离世后偷偷换人结算")
    assert(Simulation.AssignRelicExecutor(interruptedRun, interrupted.instanceId, 2) and Simulation.ResumeRelicStory(interruptedRun, interrupted.instanceId))
    local resumedJade = assert(findEvent(interruptedRun, "jade_search", interrupted.instanceId))
    assert(Simulation.ResolveEvent(interruptedRun, resumedJade.instanceId, "search", interruptedProfile), "玉佩执行人离世后不能重新安排查访")

    local custodyRun, custodyProfile = fresh()
    local custody = custodyRun.relicInstances[1]
    assert(Simulation.AssignRelicExecutor(custodyRun, custody.instanceId, 2))
    custodyRun.members[1].age, custodyRun.rngState = 89, 1
    assert(Simulation.AdvanceYear(custodyRun, custodyProfile) and custodyRun.members[1].alive == false and custody.custodianId == nil, "保管人离世后物件没有回收入家中")
    assert(Simulation.TransferRelic(custodyRun, custody.instanceId, 2) and custody.custodianId == 2, "回收入家中的物件不能重新托付")

    local soldRun, soldProfile = fresh()
    local sold = addRelic(soldRun, "jade", "完成一封旧约")
    assert(Simulation.StartJadeSearch(soldRun, sold.instanceId))
    local soldEvent = assert(findEvent(soldRun, "jade_search", sold.instanceId))
    local reputation = soldRun.reputation
    assert(Simulation.SellRelic(soldRun, sold.instanceId) and soldEvent.status == "cancelled")
    assert(not Simulation.ResolveEvent(soldRun, soldEvent.instanceId, "search", soldProfile) and not soldRun.flags.jadeReunited and soldRun.reputation == reputation, "出售后的玉佩仍可结算重逢奖励")

    assert(State.Save(notesProfile, State.NewDraft(), notesRun))
    local loaded = assert(State.Load())
    local savedNotes = nil; for _, instance in ipairs(loaded.run.relicInstances) do if instance.definitionId == "notes" then savedNotes = instance end end
    assert(savedNotes and savedNotes.stage == "printed" and savedNotes.executorId == notes.executorId and loaded.profile.unlockedRelicIds.notes, "存档重启后医案的阶段、执行人或资格丢失")

    local app = App.New(); app.profile, app.draft, app.run, app.screen, app.gameTab = notesProfile, State.NewDraft(), notesRun, "game", "relics"; app:Render()
    assert(find(UI.root, "本局物件") and find(UI.root, "已解锁的下局资格") and find(UI.root, "阶段：") and find(UI.root, "指定执行人"), "藏阁没有分开本局实体、下局资格、阶段和执行人")
    return { basic = { book = book.instanceId, letter = letter.instanceId }, plan = true, newbook = true, jade = true, notes = true, pauseResume = true, executorRecovery = true, saleCancels = true }
end

local function restart()
    local app = App.New(); app:Load()
    assert(app.run and app.profile and app.profile.unlockedRelicIds.notes, "重启后收藏或本局物件丢失")
    return { year = app.run.yearIndex, relics = #app.run.relicInstances, notesUnlocked = app.profile.unlockedRelicIds.notes }
end

return { run = run, restart = restart }
