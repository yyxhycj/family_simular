local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Art = require "Jiaye.Art"

local Outcomes = {}

local function member(run, memberId)
    return State.FindMember(run.members, memberId)
end

local function livingAdult(run, memberId)
    local value = member(run, memberId)
    if value and value.alive and State.IsAdult(value) then return value end
    return nil
end

local function addStat(value, stat, amount)
    if not value or type(value.stats) ~= "table" then return 0 end
    local before = value.stats[stat] or 0
    local after = math.min(Data.LIMIT, before + math.max(0, amount or 0))
    value.stats[stat] = after
    return after - before
end

local function relicText(ctx, run, instanceId, fallback)
    local instance = ctx.instance(run, instanceId)
    local form = instance and ctx.form(instance)
    return form and form.name or fallback or "信物"
end

local function addFact(ctx, run, kind, text, memberIds, detail)
    local ids = {}
    for _, memberId in ipairs(memberIds or {}) do
        if memberId ~= nil then table.insert(ids, memberId) end
    end
    detail = detail or {}
    if detail.relicInstanceId and not detail.familyId then
        local instance = ctx.instance(run, detail.relicInstanceId)
        local form = instance and ctx.form(instance)
        if form then detail.familyId = form.familyId end
    end
    return ctx.fact(run, kind, text, ids, detail)
end

local function upgrade(ctx, run, profile, instance, formId, sourceText, detail)
    local form = ctx.formById(formId)
    instance.formId = form.id
    instance.relicFamilyId = form.familyId
    instance.tier = form.tier
    instance.branch = form.branch
    instance.definitionId = form.legacyId or form.id
    instance.status = "held"
    instance.availability = "usable"
    instance.sealed = false
    instance.taskId = nil
    ctx.unlock(profile, form.id)
    detail = detail or {}
    detail.familyId = form.familyId
    detail.relicInstanceId = instance.instanceId
    addFact(ctx, run, "relic_upgrade", sourceText, { instance.executorId, instance.custodianId }, detail)
end

local function addInstance(ctx, run, profile, formId, source, custodianId, executorId)
    local instance = ctx.createInstance(run, formId, source, custodianId, executorId)
    if instance then ctx.unlock(profile, formId) end
    return instance
end

local function finishTask(task, run)
    task.status = "settled"
    task.settledYear = run.yearIndex
    task.remainingWorkYears = 0
    task.completedWorkYears = task.totalWorkYears
end

local function projectFact(ctx, run, task, text, memberIds)
    local proof = ctx.recordProject(run, task)
    if proof then task.projectProof = State.Copy(proof) end
    return proof
end

local function transaction(ctx, run, category, money, grain, details)
    return ctx.transaction(run, category, money or 0, grain or 0, details or {})
end

function Outcomes.ApplyInstant(ctx, run, profile, actionId, input)
    local instance = input.instanceId and ctx.instance(run, input.instanceId) or nil
    local executor = input.executorId and livingAdult(run, input.executorId) or nil
    local form = instance and ctx.form(instance) or nil

    if actionId == "genealogy.bind_verified_pages" then
        if not instance or instance.relicFamilyId ~= "genealogy" then return false, "缺页证据对应的族谱不存在。" end
        if input.branch == "defer" then return true, "补入结果暂存，ready 状态保持不变。" end
        upgrade(ctx, run, profile, instance, "genealogy.2", "缺页已经核实，旧谱补入了同一册家谱。", {
            actionId = actionId, relicInstanceId = instance.instanceId, outcome = "book_reconstructed",
        })
        run.flags = run.flags or {}
        run.flags.bookRestored = true
        ctx.consumeClaim(run, "genealogy.missing_page", instance.instanceId)
        return true, "旧谱已补完，族谱升为二阶。"
    end

    if actionId == "genealogy.invite_branch" then
        local candidate = ctx.branchCandidate(run)
        if not candidate then return false, "还没有完成旁支核实。" end
        if ctx.claimConsumed(run, "genealogy.invite_branch") then return false, "本局已经接回过旁支。" end
        local age = candidate.ageAtDiscovery + math.max(0, run.yearIndex - candidate.discoveredRunYear)
        local sex = candidate.sex
        local names = sex == "男" and Data.GivenNames.male or Data.GivenNames.female
        local memberId = ctx.nextMemberId(run)
        local experience = Data.Experience("basic")
        local newMember = {
            id = memberId,
            name = candidate.name or ((sex == "男" and "旁支" or "旁支") .. names[1]),
            sex = sex,
            age = age,
            parents = {},
            spouseId = nil,
            talent = 2,
            focus = candidate.focus or "general",
            experienceId = "basic",
            trait = "旁支旧谱所记",
            jobId = candidate.jobId or "farm",
            alive = true,
            health = 76,
            stats = State.Copy(experience.values),
            jobYears = {},
            birthPlan = true,
            lastBirthYear = -5,
            hadHomeAfterGuard = false,
            generation = candidate.generation or 2,
            externalLineage = State.Copy(candidate.externalLineage),
            biography = { "旁支候选于本局第 " .. tostring(candidate.discoveredRunYear) .. " 年被核实，父母资料留在外部祖先锚点。" },
        }
        Art.Assign(newMember, run.runId, run.artVersion)
        table.insert(run.members, newMember)
        run.metrics = run.metrics or {}
        run.metrics.branchInvites = (run.metrics.branchInvites or 0) + 1
        ctx.consumeClaim(run, "genealogy.invite_branch", instance and instance.instanceId or "genealogy")
        addFact(ctx, run, "relic_branch_joined", "旁支 " .. newMember.name .. " 依据旧谱核实后归家。", { executor and executor.id or run.leaderId, newMember.id }, {
            actionId = actionId, memberId = newMember.id, candidate = State.Copy(candidate), cost = 12,
        })
        return true, newMember.name .. "已正式归入家谱。"
    end

    if actionId == "ruler.copy_plan" then
        if not instance or instance.relicFamilyId ~= "ruler" then return false, "誊图需要一把有查证线索的木尺。" end
        if ctx.hasHeldFamily(run, "plan") or ctx.claimConsumed(run, "plan.first_acquired") then return false, "本局已经取得过营造图。" end
        local created = addInstance(ctx, run, profile, "plan.1", "木尺查匠号后的誊写", instance.custodianId, executor and executor.id or instance.custodianId)
        if not created then return false, "营造图无法创建。" end
        ctx.consumeClaim(run, "plan.first_acquired", created.instanceId)
        addFact(ctx, run, "relic_plan_acquired", "依照木尺留下的线索誊出一张修复的营造图。", { executor and executor.id or run.leaderId }, {
            actionId = actionId, sourceRelicInstanceId = instance.instanceId, relicInstanceId = created.instanceId, cost = 4,
        })
        return true, "一阶营造图已入藏。"
    end

    if actionId == "plan.buy_old_drawing" then
        if ctx.hasHeldFamily(run, "plan") or ctx.hasEverAcquiredFamily(run, "plan") then return false, "本局已经取得过营造图。" end
        local created = addInstance(ctx, run, profile, "plan.1", "累计六个手艺谋生人年后购得", run.leaderId, executor and executor.id or run.leaderId)
        if not created then return false, "营造图无法创建。" end
        ctx.consumeClaim(run, "plan.first_acquired", created.instanceId)
        addFact(ctx, run, "relic_plan_acquired", "家中累计六个手艺谋生人年后，购得一张修复的营造图。", { executor and executor.id or run.leaderId }, {
            actionId = actionId, relicInstanceId = created.instanceId, cost = 12,
        })
        return true, "一阶营造图已入藏。"
    end

    if actionId == "letter.confirm_delivery" then
        if not instance or instance.relicFamilyId ~= "letter" then return false, "待交付结果对应的家书不存在。" end
        upgrade(ctx, run, profile, instance, "letter.2", "旧信已经交到收件人后辈手中，家中留下了回信。", {
            actionId = actionId, relicInstanceId = instance.instanceId, outcome = "letter_delivered",
        })
        ctx.consumeClaim(run, "letter.delivered", instance.instanceId)
        return true, "家书已送达，留下了一封回信。"
    end

    if actionId == "jade.choose_final_form" then
        if not instance or instance.relicFamilyId ~= "jade" or instance.tier ~= 2 then return false, "只有二阶半佩可以选择终形。" end
        if input.branch ~= "heirloom" and input.branch ~= "alliance" then return false, "请选择合璧传家或各执半佩。" end
        local formId = input.branch == "heirloom" and "jade.3.heirloom" or "jade.3.alliance"
        upgrade(ctx, run, profile, instance, formId, input.branch == "heirloom" and "两家合璧，半枚玉佩成为传家信物。" or "两家各执半佩，旧交以盟约留存。", {
            actionId = actionId, relicInstanceId = instance.instanceId, outcome = "jade_reunited", branch = input.branch,
        })
        if input.branch == "heirloom" then run.reputation = (run.reputation or 0) + 8 end
        ctx.consumeClaim(run, "jade.reunion", instance.instanceId)
        ctx.consumeClaim(run, "jade.final_form", instance.instanceId)
        addFact(ctx, run, "relic_jade_reunited", input.branch == "heirloom" and "半枚玉佩合璧传家，旧交重续。" or "两家各执半佩，旧交以盟约重续。", { executor and executor.id or run.leaderId }, {
            actionId = actionId, relicInstanceId = instance.instanceId, branch = input.branch, reputation = input.branch == "heirloom" and 8 or 0,
        })
        return true, input.branch == "heirloom" and "玉佩已合璧，声望 +8。" or "两家各执半佩，盟约已写入家史。"
    end

    if actionId == "notes.accept_old_cases" then
        if ctx.hasHeldFamily(run, "notes") or ctx.claimConsumed(run, "notes.first_acquired") then return false, "本局已经收下过批注医案。" end
        local created = addInstance(ctx, run, profile, "notes.1", "医馆托付", executor and executor.id or run.leaderId, executor and executor.id or run.leaderId)
        if not created then return false, "批注医案无法创建。" end
        ctx.consumeClaim(run, "notes.first_acquired", created.instanceId)
        addFact(ctx, run, "relic_notes_acquired", "医馆把一册批注医案正式托付给家中。", { executor and executor.id or run.leaderId }, { actionId = actionId, familyId = "notes", relicInstanceId = created.instanceId })
        return true, "批注医案已入藏。"
    end

    if actionId == "migration.apply_discount" then
        return ctx.recordMigration(run, ctx.migrationQuote(run, input.baseCost), input)
    end

    return false, "该即时行动尚未登记结果。"
end

function Outcomes.PrepareReady(ctx, run, task)
    if task.actionId == "genealogy.trace_missing_page" then
        ctx.ensureBranchCandidate(run, task)
        task.readyActionId = "genealogy.bind_verified_pages"
        task.status = "ready"
        return "旧谱缺页已经核实，可以选择补入同一册家谱。"
    end
    if task.actionId == "letter.deliver" then
        local instance = ctx.instance(run, task.instanceId)
        if instance then instance.receiverFound = true end
        task.readyActionId = "letter.confirm_delivery"
        task.status = "ready"
        return "已经找到收件人的后辈，可以确认交付原信。"
    end
    if task.actionId == "jade.meet" then
        local instance = ctx.instance(run, task.instanceId)
        if instance then instance.meetingVerified = true end
        task.readyActionId = "jade.choose_final_form"
        task.status = "ready"
        return "相认已经完成，可以选择合璧传家或各执半佩。"
    end
    return nil
end

function Outcomes.Complete(ctx, run, profile, task)
    local instance = task.instanceId and ctx.instance(run, task.instanceId) or nil
    local executor = task.executorId and member(run, task.executorId) or nil
    local actionId = task.actionId

    if actionId == "genealogy.trace_missing_page" or actionId == "letter.deliver" or actionId == "jade.meet" then
        return "ready", Outcomes.PrepareReady(ctx, run, task)
    end

    if actionId == "genealogy.verify_branch" then
        ctx.ensureBranchCandidate(run, task)
        ctx.consumeClaim(run, "genealogy.branch_verified", task.instanceId)
        finishTask(task, run)
        return "settled", "旁支身份已经核实，候选人资料已固定保存。"
    end

    if actionId == "genealogy.upgrade_3" then
        if instance then upgrade(ctx, run, profile, instance, "genealogy.3", "族谱完成十年经营、两次真实有效交接与两代修谱人的先后整理，续修为世系谱。", {
            actionId = actionId, relicInstanceId = instance.instanceId, outcome = "genealogy_continued",
        }) end
        finishTask(task, run)
        return "settled", "族谱已升为三阶续修世系谱。"
    end

    if actionId == "genealogy.compile_chronicle" then
        run.reputation = (run.reputation or 0) + 12
        local factsSnapshot = State.Copy(run.facts or {})
        addFact(ctx, run, "family_chronicle_compiled", "三阶族谱编成家史，采用的事实快照被一并保存。", task.participantIds, {
            actionId = actionId, relicInstanceId = task.instanceId, familyId = "genealogy", reputation = 12, factsSnapshot = factsSnapshot,
        })
        ctx.consumeClaim(run, "genealogy.chronicle_compiled", task.instanceId)
        finishTask(task, run)
        return "settled", "家史编成，声望 +12。"
    end

    if actionId == "ruler.trace_mark" then
        if instance and instance.tier == 1 then
            upgrade(ctx, run, profile, instance, "ruler.2", "木尺上的匠号已经查明，尺身被重新校准。", { actionId = actionId, relicInstanceId = instance.instanceId, outcome = "ruler_calibrated", planClue = true })
            run.flags.rulerRestored = true
        end
        if instance then instance.planClue = true end
        addFact(ctx, run, "relic", "木尺匠号已查明，营造图线索已留存。", task.participantIds, { actionId = actionId, relicInstanceId = task.instanceId, outcome = "ruler_mark_verified" })
        ctx.consumeClaim(run, "ruler.mark_verified", task.instanceId)
        finishTask(task, run)
        return "settled", "木尺已校准，旧图线索已经留存。"
    end

    if actionId == "ruler.upgrade_3" then
        projectFact(ctx, run, task, "两项真实木工工程的结果已经回填到木尺的传承记录。", task.participantIds)
        if instance then upgrade(ctx, run, profile, instance, "ruler.3", "木尺经过两代使用与两项外部木工项目，重整为传家的匠尺。", { actionId = actionId, relicInstanceId = instance.instanceId, outcome = "ruler_inherited" }) end
        finishTask(task, run)
        return "settled", "木尺已升为三阶传家的匠尺。"
    end

    if actionId == "ruler.teach_successor" then
        local learner = member(run, task.learnerId)
        local masterGain = addStat(executor, "skill", 1)
        local learnerGain = addStat(learner, "skill", 6)
        transaction(ctx, run, "growth", 0, 0, { actionId = actionId, relicInstanceId = task.instanceId, masterId = executor and executor.id, learnerId = learner and learner.id, masterGain = masterGain, learnerGain = learnerGain })
        ctx.consumeClaim(run, "ruler.teach_successor", task.instanceId)
        addFact(ctx, run, "relic_apprenticeship", "师徒传艺完成，" .. (learner and learner.name or "学徒") .. "接过了木尺上的手艺。", { executor and executor.id or run.leaderId, learner and learner.id or run.leaderId }, {
            actionId = actionId, relicInstanceId = task.instanceId, masterId = executor and executor.id, learnerId = learner and learner.id, masterGain = masterGain, learnerGain = learnerGain,
        })
        finishTask(task, run)
        return "settled", "师徒传艺完成，学徒手艺 +" .. tostring(learnerGain) .. "，师父手艺 +" .. tostring(masterGain) .. "。"
    end

    if actionId == "letter.fulfil_promise" then
        if instance then upgrade(ctx, run, profile, instance, "letter.3", "旧家书的托付已经兑现，往来书札被家中保存。", {
            actionId = actionId, relicInstanceId = instance.instanceId, outcome = task.route == "grain" and "promise_kept_grain" or "promise_kept", route = task.route,
        }) end
        run.reputation = (run.reputation or 0) + 6
        run.flags = run.flags or {}
        run.flags.promiseKept = true
        ctx.consumeClaim(run, "letter.promise_kept", task.instanceId)
        if not ctx.hasEverAcquiredFamily(run, "jade") then
            local jade = addInstance(ctx, run, profile, "jade.1", "履行家书旧托付所得", instance and instance.custodianId or run.leaderId, executor and executor.id or run.leaderId)
            if jade then ctx.consumeClaim(run, "jade.gift_from_letter", jade.instanceId) end
        else
            ctx.consumeClaim(run, "jade.gift_from_letter", task.instanceId)
        end
        addFact(ctx, run, "relic_promise_kept", "家书旧托付已经兑现，声望增加 6 点。", task.participantIds, {
            actionId = actionId, relicInstanceId = task.instanceId, route = task.route, reputation = 6,
        })
        finishTask(task, run)
        return "settled", "旧托付已完成，家书升为三阶。"
    end

    if actionId == "letter.ask_aid" then
        if task.branch == "silver" then run.money = run.money + 12 else run.grain = run.grain + 8 end
        ctx.consumeClaim(run, "letter.aid", task.instanceId)
        transaction(ctx, run, "aid", task.branch == "silver" and 12 or 0, task.branch == "grain" and 8 or 0, {
            actionId = actionId, relicInstanceId = task.instanceId, branch = task.branch,
        })
        addFact(ctx, run, "relic_aid", task.branch == "silver" and "旧家书带回 12 两援银。" or "旧家书带回 8 石援粮。", { executor and executor.id or run.leaderId }, {
            actionId = actionId, relicInstanceId = task.instanceId, branch = task.branch, money = task.branch == "silver" and 12 or 0, grain = task.branch == "grain" and 8 or 0,
        })
        finishTask(task, run)
        return "settled", task.branch == "silver" and "援银已送达，银 +12 两。" or "援粮已送达，粮 +8 石。"
    end

    if actionId == "plan.small_repair" then
        run.money = run.money + 18
        local skillGain = addStat(executor, "skill", 2)
        projectFact(ctx, run, task, "旧图上的修缮活已经完成，工料与净报酬一并结算。", task.participantIds)
        transaction(ctx, run, "principal_return", 8, 0, { actionId = actionId, relicInstanceId = task.instanceId, principalReturn = 8 })
        transaction(ctx, run, "project_profit", 10, 0, { actionId = actionId, relicInstanceId = task.instanceId, netProfit = 10 })
        ctx.setCooldown(run, "plan.small_repair", 3)
        addFact(ctx, run, "relic_task_settled", "旧图活计完成，到账 18 两，办理人手艺 +" .. tostring(skillGain) .. "。", task.participantIds, { actionId = actionId, money = 18, principalReturn = 8, netProfit = 10, skillGain = skillGain })
        finishTask(task, run)
        return "settled", "修缮活完成，到账 18 两，净报酬 10 两。"
    end

    if actionId == "plan.upgrade_2" then
        projectFact(ctx, run, task, "营造图增订所依据的真实工程结果已经归档。", task.participantIds)
        if instance then upgrade(ctx, run, profile, instance, "plan.2", "营造图经过一项真实工程后完成增订。", { actionId = actionId, relicInstanceId = instance.instanceId, outcome = "plan_amended" }) end
        finishTask(task, run)
        return "settled", "营造图已升为二阶增订的营造图。"
    end

    if actionId == "plan.upgrade_3" then
        projectFact(ctx, run, task, "传世图样所依据的两项真实工程结果已经归档。", task.participantIds)
        if instance then upgrade(ctx, run, profile, instance, "plan.3", "营造图完成两代使用与两项工程后成为传世营造图。", { actionId = actionId, relicInstanceId = instance.instanceId, outcome = "plan_inherited" }) end
        finishTask(task, run)
        return "settled", "营造图已升为三阶传世营造图。"
    end

    if actionId == "plan.bridge" then
        run.money = run.money + 40
        run.reputation = (run.reputation or 0) + 10
        local skillGain = addStat(executor, "skill", 4)
        projectFact(ctx, run, task, "修桥工程完成，桥名与参与者一并留在家史。", task.participantIds)
        transaction(ctx, run, "principal_return", 24, 0, { actionId = actionId, relicInstanceId = task.instanceId, principalReturn = 24 })
        transaction(ctx, run, "project_profit", 16, 0, { actionId = actionId, relicInstanceId = task.instanceId, netProfit = 16 })
        ctx.consumeClaim(run, "plan.bridge", task.instanceId)
        addFact(ctx, run, "relic_task_settled", "修桥留名完成，到账 40 两，声望 +10。", task.participantIds, { actionId = actionId, money = 40, principalReturn = 24, netProfit = 16, reputation = 10, skillGain = skillGain })
        finishTask(task, run)
        return "settled", "修桥留名完成，到账 40 两，声望 +10。"
    end

    if actionId == "jade.verify_origin" then
        if instance then upgrade(ctx, run, profile, instance, "jade.2", "半枚玉佩的来历已由回信、见证与纹样核实。", { actionId = actionId, relicInstanceId = instance.instanceId, outcome = "jade_origin_verified" }) end
        finishTask(task, run)
        return "settled", "玉佩来历已经确证，升为二阶。"
    end

    if actionId == "notes.record_case" then
        local gain = addStat(executor, "medicine", 3)
        run.reputation = (run.reputation or 0) + 2
        transaction(ctx, run, "growth", 0, 0, { actionId = actionId, relicInstanceId = task.instanceId, memberId = executor and executor.id, medicineGain = gain })
        local caseId = "case-" .. tostring(task.id)
        addFact(ctx, run, "relic_case", "批注医案补记一例，病例与办理医者被分别记下。", task.participantIds, { actionId = actionId, relicInstanceId = task.instanceId, caseId = caseId, outcome = "success", medicineGain = gain, reputation = 2 })
        ctx.setCooldown(run, "notes.record_case", 2)
        finishTask(task, run)
        return "settled", "病例已补记，医术 +" .. tostring(gain) .. "，声望 +2。"
    end

    if actionId == "notes.upgrade_2" then
        if instance then upgrade(ctx, run, profile, instance, "notes.2", "批注医案完成三年有效使用与一例独立病例后完成校订。", { actionId = actionId, relicInstanceId = instance.instanceId, outcome = "notes_revised" }) end
        finishTask(task, run)
        return "settled", "医案已升为二阶校订医案。"
    end

    if actionId == "notes.upgrade_3" then
        local formId = task.branch == "public" and "notes.3.public" or "notes.3.private"
        if instance then upgrade(ctx, run, profile, instance, formId, task.branch == "public" and "医案完成刊印授人，校样与义诊资格一并留存。" or "医案完成家传编订，作为家学传给后人。", { actionId = actionId, relicInstanceId = instance.instanceId, outcome = task.branch == "public" and "medical_cases_published" or "medical_cases_private", branch = task.branch }) end
        if task.branch == "public" then run.reputation = (run.reputation or 0) + 12 end
        finishTask(task, run)
        return "settled", task.branch == "public" and "医案已刊印，声望 +12，开放义诊。" or "医案已整理为家传医案。"
    end

    if actionId == "notes.public_clinic" then
        local gain = addStat(executor, "medicine", 1)
        run.reputation = (run.reputation or 0) + 8
        transaction(ctx, run, "growth", 0, 0, { actionId = actionId, relicInstanceId = task.instanceId, memberId = executor and executor.id, medicineGain = gain })
        addFact(ctx, run, "relic_clinic", "公开义诊完成，医者与参与事实留在家史。", task.participantIds, { actionId = actionId, relicInstanceId = task.instanceId, outcome = "success", medicineGain = gain, reputation = 8 })
        ctx.setCooldown(run, "notes.public_clinic", 5)
        finishTask(task, run)
        return "settled", "公开义诊完成，声望 +8，医术 +" .. tostring(gain) .. "。"
    end

    return false, "任务结果没有对应的结算规则。"
end

return Outcomes
