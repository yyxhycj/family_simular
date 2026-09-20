local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Economy = require "Jiaye.Economy"
local Definitions = require "Jiaye.RelicDefinitions"
local RelicState = require "Jiaye.RelicState"
local Outcomes = require "Jiaye.RelicOutcomes"

local RelicSystem = {}

RelicSystem.VERSION = Definitions.VERSION
RelicSystem.Forms = Definitions.Forms
RelicSystem.Actions = Definitions.Actions
RelicSystem.Form = Definitions.Form
RelicSystem.Action = Definitions.Action
RelicSystem.Family = Definitions.Family
RelicSystem.LegacyForm = Definitions.LegacyForm
RelicSystem.RelicState = RelicState

local function List(value)
    return type(value) == "table" and value or {}
end

local function Map(value)
    return type(value) == "table" and value or {}
end

local function Number(value)
    return type(value) == "number" and value or 0
end

local function Integer(value)
    return type(value) == "number" and value == math.floor(value) and value >= 0
end

local function Member(run, memberId)
    return State.FindMember(run and run.members, memberId)
end

local function Alive(member)
    return type(member) == "table" and member.alive ~= false
end

local function Adult(member)
    return Alive(member) and State.IsAdult(member)
end

local function Stat(member, statId)
    local stats = Map(member and member.stats)
    if type(stats[statId]) == "number" then return stats[statId] end
    local experience = member and Data.Experience(member.experienceId)
    local values = experience and experience.values or nil
    return type(values) == "table" and Number(values[statId]) or 0
end

local function ValidMemberIds(run, ids)
    local result, seen = {}, {}
    for _, memberId in ipairs(ids or {}) do
        if memberId ~= nil and not seen[memberId] and Member(run, memberId) then
            seen[memberId] = true
            table.insert(result, memberId)
        end
    end
    return result
end

local function HasId(ids, value)
    for _, id in ipairs(ids or {}) do if id == value then return true end end
    return false
end

local function Copy(value)
    return State.Copy(value)
end

local function IsActiveTask(task)
    return task and (task.status == "active" or task.status == "paused_manual" or task.status == "paused_actor" or task.status == "paused_requirements")
end

local function IsBlockingTask(task)
    return IsActiveTask(task) or task and task.status == "ready"
end

local function Ensure(run, profile)
    local checkedRun, isNew = RelicState.EnsureRun(run)
    if not isNew then return nil, nil, "当前运行家谱未启用信物规则1.2。" end
    return checkedRun, RelicState.EnsureProfile(profile), nil
end

local function ActionRequirements(action)
    return action and action.requirements or {}
end

local function FormFor(run, instanceId)
    local instance = instanceId and RelicState.Find(run, instanceId) or nil
    return instance, instance and RelicState.Form(instance) or nil
end

local function Claim(run, key)
    return Map(run.relicClaims)[key]
end

local function ClaimConsumed(run, key)
    local claim = Claim(run, key)
    return claim == true or type(claim) == "table" and claim.consumed == true
end

local function ClaimReserved(run, key)
    local claim = Claim(run, key)
    return type(claim) == "table" and claim.reservedByTaskId ~= nil and not claim.consumed
end

local function ConsumeClaim(run, key, instanceId)
    run.relicClaims = run.relicClaims or {}
    local claim = type(run.relicClaims[key]) == "table" and run.relicClaims[key] or {}
    claim.consumed = true
    claim.instanceId = instanceId or claim.instanceId
    claim.consumedYear = run.yearIndex
    claim.reservedByTaskId = nil
    run.relicClaims[key] = claim
end

local function ReserveClaim(run, key, taskId)
    if not key then return end
    run.relicClaims = run.relicClaims or {}
    local claim = type(run.relicClaims[key]) == "table" and run.relicClaims[key] or {}
    claim.reservedByTaskId = taskId
    run.relicClaims[key] = claim
end

local function HasEverAcquiredFamily(run, familyId)
    local claim = Claim(run, familyId .. ".first_acquired")
    if claim ~= nil then return true end
    for _, instance in ipairs(List(run.relicInstances)) do
        if instance.relicFamilyId == familyId then return true end
    end
    return false
end

local function HasHeldFamily(run, familyId)
    for _, instance in ipairs(List(run.relicInstances)) do
        if instance.relicFamilyId == familyId and instance.status == "held" and instance.availability ~= "archived" and instance.availability ~= "sold" then return true end
    end
    return false
end

local function TaskById(run, taskId)
    for _, task in ipairs(List(run.relicTasks)) do if task.id == taskId then return task end end
    return nil
end

local function TaskForInstance(run, instanceId)
    local instance = RelicState.Find(run, instanceId)
    if instance and instance.taskId then return TaskById(run, instance.taskId) end
    for _, task in ipairs(List(run.relicTasks)) do
        if IsBlockingTask(task) and task.instanceId == instanceId or task.status == "active" and HasId(task.attachedInstanceIds, instanceId) then return task end
    end
    for _, project in pairs(Map(run.relicExternalProjects)) do
        if project.status == "active" and HasId(project.attachedInstanceIds, instanceId) then return project end
    end
    return nil
end

local function TaskForAction(run, actionId, input)
    for _, task in ipairs(List(run.relicTasks)) do
        if task.actionId == actionId and IsBlockingTask(task)
            and task.instanceId == input.instanceId
            and task.executorId == input.executorId
            and task.route == input.route
            and task.branch == input.branch then
            return task
        end
    end
    return nil
end

local function MemberTaskCount(run, memberId)
    local count = 0
    for _, task in ipairs(List(run.relicTasks)) do
        if task.status == "active" and (task.executorId == memberId or HasId(task.participantIds, memberId)) then count = count + 1 end
    end
    for _, project in pairs(Map(run.relicExternalProjects)) do
        if project.status == "active" and HasId(project.participantIds, memberId) then count = count + 1 end
    end
    return count
end

local function Cooldown(run, key)
    local value = Map(run.relicCooldowns)[key]
    if type(value) == "table" then return value end
    if type(value) == "number" then return { nextAcceptYear = value } end
    return nil
end

local function CooldownBlocked(run, key)
    local value = Cooldown(run, key)
    return value and Number(run.yearIndex) < Number(value.nextAcceptYear)
end

local function SetCooldown(run, key, years)
    run.relicCooldowns = run.relicCooldowns or {}
    run.relicCooldowns[key] = { lastSettledYear = run.yearIndex, nextAcceptYear = run.yearIndex + years }
end

local function HasFact(run, predicate)
    for _, fact in ipairs(List(run.facts)) do if predicate(fact) then return true end end
    return false
end

local function CountFacts(run, predicate)
    local count = 0
    for _, fact in ipairs(List(run.facts)) do if predicate(fact) then count = count + 1 end end
    return count
end

local function Distinct(values)
    local seen, result = {}, {}
    for _, value in ipairs(values or {}) do
        if value ~= nil and not seen[value] then seen[value] = true; table.insert(result, value) end
    end
    return result
end

local function UseFacts(run, instanceId)
    local result = {}
    for _, fact in ipairs(List(run.relicUseFacts)) do if fact.instanceId == instanceId then table.insert(result, fact) end end
    return result
end

local function ProjectFacts(run, instanceId)
    local result = {}
    for _, fact in ipairs(List(run.relicProjectFacts)) do
        if fact.instanceId == instanceId or HasId(fact.attachedInstanceIds, instanceId) then table.insert(result, fact) end
    end
    return result
end

local function JobYears(run, jobId)
    local count = 0
    for _, member in ipairs(List(run.members)) do count = count + Number(Map(member.jobYears)[jobId]) end
    return count
end

local function EffectiveHandovers(run)
    local count = 0
    local seen = {}
    for _, term in ipairs(List(run.leaderTerms)) do
        if term.realHandover and term.memberId and not seen[term.memberId] then
            seen[term.memberId] = true
            count = count + 1
        end
    end
    return count
end

local function GenerationUse(run, instanceId)
    local facts = UseFacts(run, instanceId)
    for _, earlier in ipairs(facts) do
        for _, later in ipairs(facts) do
            if earlier.memberId ~= later.memberId and earlier.generation < later.generation and earlier.runYear < later.runYear then
                return { earlier.generation, later.generation }
            end
        end
    end
    return #facts > 0 and { facts[1].generation } or {}
end

local function CostCopy(cost)
    return { money = math.max(0, math.tointeger(Number(cost and cost.money)) or 0), grain = math.max(0, math.tointeger(Number(cost and cost.grain)) or 0) }
end

local function RouteSelection(action, input, reasons)
    local route = input.route
    local branch = input.branch
    if action.routes then
        if not route then table.insert(reasons, "请选择行动路线。")
        elseif not action.routes[route] then table.insert(reasons, "行动路线无效。") end
    end
    if action.id == "letter.fulfil_promise" then branch = route end
    if action.branches and action.id ~= "genealogy.bind_verified_pages" then
        if not branch then table.insert(reasons, "请选择行动分支。")
        elseif not action.branches[branch] then table.insert(reasons, "行动分支无效。") end
    end
    if action.id == "genealogy.bind_verified_pages" and branch and branch ~= "restore" and branch ~= "defer" then table.insert(reasons, "族谱补入分支无效。") end
    return route, branch
end

local function RouteData(action, route)
    return action.routes and route and action.routes[route] or nil
end

local function TaskCost(action, route)
    local routeData = RouteData(action, route)
    return CostCopy(routeData and routeData.cost or action.cost), routeData and routeData.workYears or action.workYears
end

local function CheckStat(member, requirement, reasons)
    if requirement and Stat(member, requirement.id) < requirement.min then table.insert(reasons, (Data.FocusNames[requirement.id] or "能力") .. " " .. tostring(Stat(member, requirement.id)) .. "/" .. tostring(requirement.min) .. "。") end
end

local function CheckMemberRequirements(run, action, input, instance, form, reasons, ongoing)
    local req = ActionRequirements(action)
    local executorId = input.executorId or (instance and instance.userId) or run.leaderId
    local executor = Member(run, executorId)
    if req.adult and not Adult(executor) then table.insert(reasons, "执行人必须是在世成年人。") end
    if req.alive and not Alive(executor) then table.insert(reasons, "执行人必须在世。") end
    if req.stat then CheckStat(executor, req.stat, reasons) end
    if req.anyStat then
        local ok = false
        for _, candidate in ipairs(req.anyStat) do if Stat(executor, candidate.id) >= candidate.min then ok = true end end
        if not ok then table.insert(reasons, "执行人的学识或经营能力不足。") end
    end
    if req.job and executor and executor.jobId ~= req.job then table.insert(reasons, "执行人的当前主业不符合行动要求。") end
    if req.branch and (not form or form.branch ~= req.branch) then table.insert(reasons, "只有刊行医案可以承接公开义诊。") end
    if req.currentUser then
        local current = executor
        if not current or not Adult(current) or current.jobId ~= req.currentUser.job then table.insert(reasons, "当前使用人不符合职业要求。") end
        CheckStat(current, req.currentUser.stat, reasons)
    end
    if req.master then
        if not Adult(executor) or executor.jobId ~= req.master.job or Stat(executor, req.master.stat.id) < req.master.stat.min then table.insert(reasons, "师父必须是在世成年手艺人且手艺达到55。") end
    end
    if req.apprentice then
        local learner = Member(run, input.learnerId)
        if not Alive(learner) or Number(learner.age) < req.apprentice.minAge or learner.jobId ~= req.apprentice.job then table.insert(reasons, "学徒必须在世、满龄且当前安排为学徒。") end
        if input.learnerId == executorId then table.insert(reasons, "师父与学徒必须是两位族人。") end
    end
    if req.branchCandidate and not Claim(run, "genealogy.branch_candidate") then table.insert(reasons, "还没有固定的旁支候选。") end
    if req.clue and not ClaimConsumed(run, req.clue) then table.insert(reasons, "行动所需的前置线索尚未形成。") end
    local function progress(label, current, required)
        if required and current < required then table.insert(reasons, label .. " " .. tostring(current) .. "/" .. tostring(required) .. "。") end
    end
    progress("本局经营年数", Number(run.yearIndex), req.runYears)
    progress("真实交接", EffectiveHandovers(run), req.effectiveDistinctHandovers)
    progress("手艺谋生人年", JobYears(run, "craft"), req.craftJobYears)
    progress("实际行医人年", JobYears(run, "doctor"), req.doctorJobYears)
    if instance then
        progress("本物件实际使用年", #UseFacts(run, instance.instanceId), req.useYears)
        progress("本物件真实工程", #ProjectFacts(run, instance.instanceId), req.projects)
        progress("本医案独立病例", CountFacts(run, function(fact) return fact.kind == "relic_case" and fact.relicInstanceId == instance.instanceId end), req.cases)
    end
    if req.generationUse then
        if #GenerationUse(run, instance and instance.instanceId) < req.generationUse.generations then table.insert(reasons, "两代真实使用证据不足。") end
    end
    if req.generations and instance and #Distinct(GenerationUse(run, instance.instanceId)) < req.generations then table.insert(reasons, "两代使用或传承证据不足。") end
    if not ongoing then
        if req.moneyBelow and Number(run.money) >= req.moneyBelow then table.insert(reasons, "当前银两未达到渡难条件。") end
        if req.moneyAtLeast and Number(run.money) < req.moneyAtLeast then table.insert(reasons, "支付邮递费所需银两不足。") end
        if req.grainBelowAnnualNeed and Number(run.grain) >= Number(Economy.StandardAnnualFoodNeed(run)) then table.insert(reasons, "当前存粮未达到渡难条件。") end
    end
    if req.uniqueCase and HasFact(run, function(fact) return fact.kind == "relic_case" and fact.year == run.calendar end) then table.insert(reasons, "今年已经补记过病例。") end
    if not ongoing and form and instance and req.available and (instance.availability or "usable") ~= "usable" then table.insert(reasons, "信物当前处于封存或不可用状态。") end
    return executorId, executor
end

local function CheckAttachments(run, input, mainInstance, reasons)
    local ids = {}
    for _, instanceId in ipairs(input.attachedInstanceIds or {}) do
        if not ids[instanceId] then
            ids[instanceId] = true
            local instance = RelicState.Find(run, instanceId)
            if not instance or instance.status ~= "held" or (instance.availability or "usable") ~= "usable" then table.insert(reasons, "挂载信物必须是当前可用的在藏信物。") end
            if instance and TaskForInstance(run, instanceId) then table.insert(reasons, "挂载信物已有未结任务。") end
        end
    end
    if mainInstance and mainInstance.taskId and TaskForInstance(run, mainInstance.instanceId) then table.insert(reasons, "主信物已有未结任务。") end
end

local function CheckTier(action, form, reasons)
    if not form then return end
    local tiers = action.tiers
    if tiers then
        local allowed = false
        for _, tier in ipairs(tiers) do if tier == form.tier then allowed = true end end
        if not allowed then table.insert(reasons, "当前信物阶位不符合行动要求。") end
    end
    if action.minTier and form.tier < action.minTier then table.insert(reasons, "当前信物阶位不足。") end
    if action.maxTier and form.tier > action.maxTier then table.insert(reasons, "该行动只适用于取得信物前的路线。") end
end

local function CheckClaimAndCooldown(run, action, reasons)
    local key = action.claimKey
    if action.cooldownYears and action.cooldownYears > 0 and CooldownBlocked(run, action.id) then table.insert(reasons, "经营满 " .. tostring(Cooldown(run, action.id).nextAcceptYear) .. " 年可再次承接；当前 " .. tostring(run.yearIndex) .. " 年。") end
    if ActionRequirements(action).claimUnused and action.cooldownYears == 0 and key and (ClaimConsumed(run, key) or ClaimReserved(run, key)) then table.insert(reasons, "本局该一次性行动已经使用。") end
end

local function Transaction(run, category, money, grain, details)
    if category:sub(1, 6) ~= "relic_" then category = "relic_" .. category end
    run.relicTransactions = run.relicTransactions or {}
    local entry = Copy(details or {})
    entry.id = "relic-transaction-" .. tostring(#run.relicTransactions + 1)
    entry.category, entry.money, entry.grain = category, money or 0, grain or 0
    entry.runYear = run.relicSettlementYear or run.yearIndex + 1
    table.insert(run.relicTransactions, entry)
    local labels = { relic_principal_return = "任务本金返还", relic_project_profit = "任务净报酬", relic_aid = "外部援助", relic_growth = "信物事务能力成长" }
    State.AddFact(run, "relic_account", entry.label or labels[category] or category, ValidMemberIds(run, entry.memberIds), Copy(entry))
    return entry
end

local function RecordProject(run, task)
    run.relicProjectFacts = run.relicProjectFacts or {}
    local proof = {}
    for _, instanceId in ipairs(task.attachedInstanceIds or {}) do
        local duplicate = false
        for _, existing in ipairs(run.relicProjectFacts) do
            if existing.projectId == task.id and existing.instanceId == instanceId then duplicate = true end
        end
        local workYears, members = {}, {}
        for _, work in ipairs(task.workFacts or {}) do
            local userId = Map(work.boundUsers)[instanceId]
            if userId and HasId(work.memberIds, userId) and Map(work.qualifiedUsers)[instanceId] then
                table.insert(workYears, work.runYear)
                table.insert(members, userId)
            end
        end
        if not duplicate and #workYears > 0 then
            local fact = { projectId = task.id, instanceId = instanceId, participantIds = Distinct(members), workYears = workYears, outcome = "success", settledYear = run.yearIndex }
            table.insert(run.relicProjectFacts, fact)
            table.insert(proof, Copy(fact))
        end
    end
    return proof
end

local function MakeContext()
    local ctx = {}
    ctx.instance = function(run, id) return RelicState.Find(run, id) end
    ctx.form = function(instance) return RelicState.Form(instance) end
    ctx.formById = function(id) return Definitions.Form(id) end
    ctx.createInstance = function(run, formId, source, custodianId, userId)
        local instance, message = RelicState.CreateInstance(run, formId, source, custodianId, userId)
        if instance and instance.relicFamilyId and not RelicState.Primary(run, instance.relicFamilyId) then run.primaryRelics[instance.relicFamilyId] = instance.instanceId end
        return instance, message
    end
    ctx.unlock = function(profile, formId)
        local form = Definitions.Form(formId)
        profile.unlockedRelicForms = profile.unlockedRelicForms or {}
        profile.unlockedRelicForms[formId] = true
        if form and form.legacyId then profile.unlockedRelicIds = profile.unlockedRelicIds or {}; profile.unlockedRelicIds[form.legacyId] = true end
    end
    ctx.fact = function(run, kind, text, memberIds, detail) return State.AddFact(run, kind, text, ValidMemberIds(run, memberIds), detail) end
    ctx.consumeClaim = function(run, key, instanceId)
        local action = Definitions.Action(key)
        return ConsumeClaim(run, action and action.claimKey or key, instanceId)
    end
    ctx.claimConsumed = function(run, key)
        local action = Definitions.Action(key)
        return ClaimConsumed(run, action and action.claimKey or key)
    end
    ctx.transaction = Transaction
    ctx.recordProject = RecordProject
    ctx.hasHeldFamily = HasHeldFamily
    ctx.hasEverAcquiredFamily = HasEverAcquiredFamily
    ctx.setCooldown = SetCooldown
    ctx.migrationQuote = RelicSystem.MigrationQuote
    ctx.recordMigration = function(run, quote, input) return RelicSystem.RecordMigration(run, quote, input and input.placeId) end
    ctx.nextMemberId = function(run)
        local nextId = Number(run.nextId)
        if nextId < 1 then nextId = #List(run.members) + 1 end
        while Member(run, nextId) do nextId = nextId + 1 end
        run.nextId = nextId + 1
        return nextId
    end
    ctx.branchCandidate = function(run)
        local claim = Claim(run, "genealogy.branch_candidate")
        return type(claim) == "table" and claim.candidate or nil
    end
    ctx.ensureBranchCandidate = function(run, task)
        run.relicClaims = run.relicClaims or {}
        local claim = Claim(run, "genealogy.branch_candidate")
        if type(claim) == "table" and claim.candidate then return claim.candidate end
        local sex = State.Random(run, 0, 1) == 0 and "男" or "女"
        local names = sex == "男" and Data.GivenNames.male or Data.GivenNames.female
        local name = run.openingSnapshot.family .. names[math.tointeger(State.Random(run, 1, #names))]
        local candidate = {
            id = "branch-candidate-" .. tostring(task.id), name = name, sex = sex,
            ageAtDiscovery = State.Random(run, 18, 40), discoveredRunYear = run.yearIndex,
            generation = 2, talent = 2, experienceId = "basic", jobId = "farm",
            externalLineage = { ancestorId = "genealogy-branch-" .. tostring(task.id), relation = "旁支" },
            generationEvidence = "由本次核对旁支行动固定，年龄按本局经营年增长。",
        }
        run.relicClaims["genealogy.branch_candidate"] = { candidate = candidate, generatedByTaskId = task.id, generation = candidate.generation }
        return candidate
    end
    return ctx
end

function RelicSystem.Quote(run, actionId, input)
    local quote = { allowed = false, reasons = {}, cost = { money = 0, grain = 0 }, workYears = 0, sealsRelic = false, preview = "", actionId = actionId }
    if type(run) ~= "table" or not RelicState.IsNew(run) then table.insert(quote.reasons, "当前运行家谱未启用信物规则1.2。") return quote end
    if run.ending then table.insert(quote.reasons, "家史已落笔，本局只读。") return quote end
    if type(input) ~= "table" then table.insert(quote.reasons, "行动输入无效。") return quote end
    local action = Definitions.Action(actionId)
    if not action then table.insert(quote.reasons, "行动编号未登记。") return quote end
    quote.preview = action.preview and action.preview.outcome or action.name
    local instance, form = FormFor(run, input.instanceId)
    if action.id ~= "plan.buy_old_drawing" and action.id ~= "notes.accept_old_cases" and not instance then table.insert(quote.reasons, "行动所需的信物不存在。") end
    if instance then
        if instance.status ~= "held" then table.insert(quote.reasons, "信物当前不在家中保管。") end
        if instance.availability ~= "usable" and action.id ~= "genealogy.bind_verified_pages" and action.id ~= "letter.confirm_delivery" and action.id ~= "jade.choose_final_form" then table.insert(quote.reasons, "信物当前不可用。") end
        if action.familyId ~= instance.relicFamilyId then table.insert(quote.reasons, "行动与信物成长线不匹配。") end
        CheckTier(action, form, quote.reasons)
        local blocking = TaskForInstance(run, instance.instanceId)
        if blocking and not (blocking.status == "ready" and blocking.readyActionId == actionId) then table.insert(quote.reasons, "信物已有未结任务。") end
    end
    local route, branch = RouteSelection(action, input, quote.reasons)
    quote.route, quote.branch = route, branch
    quote.cost, quote.workYears = TaskCost(action, route)
    quote.sealsRelic = action.sealsRelic == true or actionId == "ruler.trace_mark" and form and form.tier == 1 or false
    if action.id == "letter.fulfil_promise" and route ~= "books" and route ~= "grain" then table.insert(quote.reasons, "兑现旧托付只能选择 books 或 grain。") end
    if action.id == "letter.ask_aid" and branch ~= "silver" and branch ~= "grain" then table.insert(quote.reasons, "渡难书信只能选择 silver 或 grain。") end
    if action.id == "plan.buy_old_drawing" or action.id == "notes.accept_old_cases" then
        if HasEverAcquiredFamily(run, action.familyId) then table.insert(quote.reasons, "本局该成长线已经取得过信物。") end
    end
    CheckClaimAndCooldown(run, action, quote.reasons)
    local executorId, executor = CheckMemberRequirements(run, action, input, instance, form, quote.reasons)
    quote.executorId = executorId
    if action.id == "genealogy.bind_verified_pages" or action.id == "letter.confirm_delivery" or action.id == "jade.choose_final_form" then
        local ready = nil
        for _, task in ipairs(List(run.relicTasks)) do if task.status == "ready" and task.readyActionId == action.id and task.instanceId == input.instanceId then ready = task end end
        if not ready then table.insert(quote.reasons, "当前没有可确认的 ready 结果。") else quote.readyTaskId = ready.id end
    end
    if executorId and MemberTaskCount(run, executorId) >= 1 and quote.workYears > 0 then
        table.insert(quote.reasons, "执行人已有一项进行中的信物事务。")
    end
    if input.learnerId and MemberTaskCount(run, input.learnerId) >= 1 and quote.workYears > 0 then table.insert(quote.reasons, "学徒已有一项进行中的事务。") end
    if quote.workYears > 0 then
        for _, id in ipairs(input.participantIds or {}) do
            if not Adult(Member(run, id)) or MemberTaskCount(run, id) > 0 then table.insert(quote.reasons, "额外参与人需要在世成年且未被其他事务占用。") end
        end
    end
    if quote.readyTaskId and not Adult(executor) then table.insert(quote.reasons, "请由当前在世成年人确认结果。") end
    if action.id == "genealogy.invite_branch" and not Claim(run, "genealogy.branch_candidate") then table.insert(quote.reasons, "旁支候选尚未生成。") end
    if action.id == "genealogy.invite_branch" and HasEverAcquiredFamily(run, "genealogy") == false then table.insert(quote.reasons, "本行动需要本局已有族谱实例。") end
    if action.id == "genealogy.upgrade_3" and #GenerationUse(run, input.instanceId) < 2 then table.insert(quote.reasons, "续修需要两代真实修谱人年。") end
    if action.id == "ruler.upgrade_3" and #ProjectFacts(run, input.instanceId) < 2 then table.insert(quote.reasons, "重整匠尺需要两项真实工程证据。") end
    if action.id == "plan.upgrade_2" or action.id == "plan.upgrade_3" then CheckAttachments(run, input, instance, quote.reasons) end
    if action.id == "plan.small_repair" or action.id == "plan.bridge" then CheckAttachments(run, input, instance, quote.reasons) end
    if action.id == "notes.upgrade_3" and branch ~= "private" and branch ~= "public" then table.insert(quote.reasons, "医案三阶必须选择 private 或 public。") end
    if action.id == "jade.choose_final_form" and branch ~= "heirloom" and branch ~= "alliance" then table.insert(quote.reasons, "玉佩终形必须选择 heirloom 或 alliance。") end
    if Number(run.money) < quote.cost.money then table.insert(quote.reasons, "现银不足。") end
    if Number(run.grain) < quote.cost.grain then table.insert(quote.reasons, "存粮不足。") end
    if quote.readyTaskId then quote.cost = { money = 0, grain = 0 }; quote.workYears = 0; quote.sealsRelic = false end
    quote.allowed = #quote.reasons == 0
    return quote
end

local function NextTaskId(run)
    local number = #List(run.relicTasks) + 1
    local id = "relic-task-" .. tostring(number)
    while TaskById(run, id) do number = number + 1; id = "relic-task-" .. tostring(number) end
    return id
end

local function AddTaskFact(run, task, text)
    State.AddFact(run, "relic", text, ValidMemberIds(run, task.participantIds), {
        outcome = task.actionId, actionId = task.actionId, taskId = task.id, relicInstanceId = task.instanceId,
        attachedInstanceIds = Copy(task.attachedInstanceIds), runYear = task.acceptedYear,
    })
end

local function ReleaseTaskInstances(run, task)
    local ids = { task.instanceId }
    for _, instanceId in ipairs(task.attachedInstanceIds or {}) do if not HasId(ids, instanceId) then table.insert(ids, instanceId) end end
    for _, instanceId in ipairs(ids) do
        local instance = RelicState.Find(run, instanceId)
        if instance and instance.taskId == task.id then instance.taskId = nil; instance.sealed = false; if instance.status == "held" then instance.availability = "usable" end end
    end
end

local function ReleaseAttachments(run, task)
    for _, id in ipairs(task.attachedInstanceIds or {}) do
        if id ~= task.instanceId then
            local item = RelicState.Find(run, id)
            if item and item.taskId == task.id then item.taskId = nil end
        end
    end
end

local function SettleTask(run, task)
    if task.status == "settled" then ReleaseTaskInstances(run, task) end
end

function RelicSystem.Start(run, profile, actionId, input)
    local checkedRun, checkedProfile, errorMessage = Ensure(run, profile)
    if not checkedRun then return false, errorMessage end
    input = type(input) == "table" and input or {}
    local duplicate = TaskForAction(run, actionId, input)
    if duplicate then return true, duplicate.status == "ready" and "结果已就绪。" or "该信物事务已经受理。" end
    local quote = RelicSystem.Quote(run, actionId, input)
    if not quote.allowed then return false, table.concat(quote.reasons, "；") end
    local action = Definitions.Action(actionId)
    if quote.readyTaskId then
        local sourceTask = TaskById(run, quote.readyTaskId)
        if actionId == "genealogy.bind_verified_pages" and input.branch == "defer" then return true, "查访结果已暂存，今后可免费补入。" end
        local ok, message = Outcomes.ApplyInstant(MakeContext(), run, checkedProfile, actionId, input)
        if not ok then return false, message end
        sourceTask.status = "settled"
        sourceTask.settledYear = run.yearIndex
        sourceTask.totalWorkYears = math.tointeger(sourceTask.totalWorkYears) or 0
        sourceTask.completedWorkYears = sourceTask.totalWorkYears
        sourceTask.remainingWorkYears = 0
        ReleaseTaskInstances(run, sourceTask)
        AddTaskFact(run, sourceTask, message)
        return true, message
    end
    if quote.cost.money > 0 then run.money = Number(run.money) - quote.cost.money end
    if quote.cost.grain > 0 then run.grain = Number(run.grain) - quote.cost.grain end
    if quote.workYears == 0 then
        local ok, message = Outcomes.ApplyInstant(MakeContext(), run, checkedProfile, actionId, input)
        if not ok then
            run.money = Number(run.money) + quote.cost.money
            run.grain = Number(run.grain) + quote.cost.grain
            return false, message
        end
        if action.claimKey and action.cooldownYears == 0 and action.id ~= "ruler.copy_plan" and action.id ~= "plan.buy_old_drawing" and action.id ~= "notes.accept_old_cases" then ConsumeClaim(run, action.claimKey, input.instanceId) end
        if action.cooldownYears and action.cooldownYears > 0 then SetCooldown(run, action.id, action.cooldownYears) end
        if quote.cost.money > 0 or quote.cost.grain > 0 then Transaction(run, "relic_action_cost", -quote.cost.money, -quote.cost.grain, { actionId = actionId, instanceId = input.instanceId, label = action.name .. "费用" }) end
        return true, message
    end
    local taskId = NextTaskId(run)
    local participants = ValidMemberIds(run, input.participantIds or {})
    if quote.executorId and not HasId(participants, quote.executorId) then table.insert(participants, quote.executorId) end
    if input.learnerId and not HasId(participants, input.learnerId) then table.insert(participants, input.learnerId) end
    local task = {
        id = taskId, actionId = actionId, instanceId = input.instanceId, executorId = quote.executorId,
        participantIds = participants, attachedInstanceIds = Copy(input.attachedInstanceIds or {}), paid = Copy(quote.cost),
        totalWorkYears = math.tointeger(quote.workYears), completedWorkYears = 0, remainingWorkYears = math.tointeger(quote.workYears),
        sealsRelic = quote.sealsRelic, route = quote.route, branch = quote.branch, status = "active", acceptedYear = run.yearIndex,
        settledYear = nil, workFacts = {}, learnerId = input.learnerId,
    }
    if actionId == "plan.small_repair" or actionId == "plan.bridge" then
        if not HasId(task.attachedInstanceIds, task.instanceId) then table.insert(task.attachedInstanceIds, task.instanceId) end
    end
    table.insert(run.relicTasks, task)
    if quote.cost.money > 0 or quote.cost.grain > 0 then Transaction(run, "relic_action_cost", -quote.cost.money, -quote.cost.grain, { actionId = actionId, instanceId = input.instanceId, taskId = taskId, label = action.name .. "费用" }) end
    if action.claimKey and action.cooldownYears == 0 then ReserveClaim(run, action.claimKey, task.id) end
    if input.instanceId then
        local instance = RelicState.Find(run, input.instanceId)
        if instance then instance.taskId = task.id; if quote.sealsRelic then instance.availability = "sealed"; instance.sealed = true end end
    end
    for _, instanceId in ipairs(task.attachedInstanceIds) do
        local attached = RelicState.Find(run, instanceId)
        if attached then attached.taskId = task.id; if quote.sealsRelic then attached.availability = "sealed"; attached.sealed = true end end
    end
    AddTaskFact(run, task, "信物行动已受理：" .. tostring(action.name) .. "。")
    return true, "已受理“" .. tostring(action.name) .. "”，预计需要 " .. tostring(task.totalWorkYears) .. " 个经营年度。"
end

function RelicSystem.Pause(run, taskId)
    if run.ending then return false, "家史已落笔，本局只读。" end
    local task = TaskById(run, taskId)
    if not task or task.status ~= "active" then return false, "只有进行中的任务可以暂停。" end
    task.status = "paused_manual"
    ReleaseAttachments(run, task)
    AddTaskFact(run, task, "信物事务已暂停，保留已付费用与实际进度。")
    return true, "任务已暂停。"
end

function RelicSystem.Resume(run, taskId, input)
    if run.ending then return false, "家史已落笔，本局只读。" end
    local task = TaskById(run, taskId)
    if not task or (task.status ~= "paused_manual" and task.status ~= "paused_actor" and task.status ~= "paused_requirements") then return false, "当前任务无法恢复。" end
    input = type(input) == "table" and input or {}
    local candidate = Copy(task)
    candidate.executorId = input.executorId or task.executorId
    candidate.learnerId = input.learnerId or task.learnerId
    local reasons, action = {}, Definitions.Action(task.actionId)
    local instance, form = FormFor(run, task.instanceId)
    CheckMemberRequirements(run, action, candidate, instance, form, reasons, true)
    if MemberTaskCount(run, candidate.executorId) > 0 then table.insert(reasons, "办理人已有进行中的额外事务。") end
    if candidate.learnerId and MemberTaskCount(run, candidate.learnerId) > 0 then table.insert(reasons, "学徒已有进行中的额外事务。") end
    for _, id in ipairs(task.attachedInstanceIds or {}) do
        if id ~= task.instanceId then
            local attached = RelicState.Find(run, id)
            if not attached or attached.status ~= "held" or attached.availability ~= "usable" or TaskForInstance(run, id) then table.insert(reasons, "项目所附信物当前无法参与。") end
        end
    end
    if #reasons > 0 then return false, table.concat(reasons, "；") end
    task.executorId, task.learnerId = candidate.executorId, candidate.learnerId
    task.participantIds = ValidMemberIds(run, { task.executorId, task.learnerId })
    task.status = "active"
    task.pauseReason = nil
    for _, id in ipairs(task.attachedInstanceIds or {}) do RelicState.Find(run, id).taskId = task.id end
    AddTaskFact(run, task, "信物事务继续办理，沿用已付费用与剩余工期。")
    return true, "任务已恢复。"
end

function RelicSystem.Cancel(run, taskId)
    if run.ending then return false, "家史已落笔，本局只读。" end
    local task = TaskById(run, taskId)
    if not task or task.status == "settled" or task.status == "cancelled" then return false, "当前任务无法放弃。" end
    task.status = "cancelled"
    task.settledYear = run.yearIndex
    ReleaseTaskInstances(run, task)
    local claim = task.actionId and Definitions.Action(task.actionId).claimKey or nil
    local value = claim and Claim(run, claim)
    if type(value) == "table" and value.reservedByTaskId == task.id then value.reservedByTaskId = nil end
    AddTaskFact(run, task, "已放弃信物事务，物件恢复原阶可用状态，已付费用不退。")
    return true, "任务已放弃，已付费用不退。"
end

function RelicSystem.Sell(run, instanceId)
    if run.ending then return false, "家史已落笔，本局只读。" end
    local instance = RelicState.Find(run, instanceId)
    if not instance or instance.status ~= "held" then return false, "信物当前无法出售。" end
    local task = TaskForInstance(run, instanceId)
    if task then
        if task.external then task.status = "cancelled" else RelicSystem.Cancel(run, task.id) end
    end
    local form = RelicState.Form(instance)
    if not form then return false, "信物形态不存在。" end
    instance.status = "sold"
    instance.availability = "usable"
    instance.userId = nil
    instance.custodianId = nil
    instance.soldYear = run.yearIndex
    run.money = Number(run.money) + Number(form.saleSilver)
    if run.primaryRelics[instance.relicFamilyId] == instanceId then run.primaryRelics[instance.relicFamilyId] = nil end
    Transaction(run, "relic_sale", form.saleSilver, 0, { instanceId = instanceId, label = form.name .. "出售所得" })
    State.AddFact(run, "relic", form.name .. "已出售，所得银两归入家中公库。", {}, { outcome = "relic.sold", actionId = "relic.sell", relicInstanceId = instanceId, money = form.saleSilver })
    return true, "已出售“" .. form.name .. "”，银 +" .. tostring(form.saleSilver) .. "两。"
end

function RelicSystem.AssignUser(run, instanceId, memberId)
    if run.ending then return false, "家史已落笔，本局只读。" end
    local instance = RelicState.Find(run, instanceId)
    if not instance or instance.status ~= "held" then return false, "信物当前无法安排使用者。" end
    if memberId == nil then instance.userId = nil; return true, "已改为家中保管，暂不指定使用者。" end
    local member = Member(run, memberId)
    local ok, reason = RelicState.EligibleUser(run, instance, member)
    if not ok then return false, reason end
    instance.userId = memberId
    return true, "已指定使用者。"
end

function RelicSystem.AssignCustodian(run, instanceId, memberId)
    if run.ending then return false, "家史已落笔，本局只读。" end
    local instance = RelicState.Find(run, instanceId)
    local member = Member(run, memberId)
    if not instance or instance.status ~= "held" then return false, "信物当前无法安排保管人。" end
    if memberId == nil then instance.custodianId = nil; return true, "物件已改为家中保管。" end
    if not Adult(member) then return false, "保管人必须是在世成年人。" end
    instance.custodianId = memberId
    return true, "已指定保管人。"
end

function RelicSystem.SetPrimary(run, instanceId)
    if run.ending then return false, "家史已落笔，本局只读。" end
    local instance = RelicState.Find(run, instanceId)
    if not instance or instance.status ~= "held" then return false, "只有在藏信物可以设为主件。" end
    run.primaryRelics = run.primaryRelics or {}
    run.primaryRelics[instance.relicFamilyId] = instanceId
    return true, "已设为该成长线主件。"
end

local function LedgerRows(ledger)
    local rows = {}
    for _, row in ipairs(List(ledger and ledger.members)) do rows[row.memberId] = row end
    return rows
end

local function ActualWork(row)
    return row and row.executed == true
end

local function ApplyAnnual(run, yearStart, ledger)
    local rows = LedgerRows(ledger)
    run.relicUseFacts = run.relicUseFacts or {}
    ledger.relicEffects = ledger.relicEffects or {}
    for _, family in ipairs(Definitions.Families) do
        local startPrimary = RelicState.Primary(yearStart, family.id)
        if startPrimary and startPrimary.status == "held" and (startPrimary.availability or "usable") == "usable" and startPrimary.userId then
            local startMember = Member(yearStart, startPrimary.userId)
            local currentMember = Member(run, startPrimary.userId)
            local row = rows[startPrimary.userId]
            local form = RelicState.Form(startPrimary)
            local ok = startMember and currentMember and Alive(startMember) and Alive(currentMember) and RelicState.EligibleUser(yearStart, startPrimary, startMember) and ActualWork(row)
            local tracksYears = form and (form.familyId == "ruler" or form.familyId == "plan" or form.familyId == "notes" or form.familyId == "genealogy" and form.tier >= 2)
            if ok and tracksYears then
                local duplicate = false
                for _, fact in ipairs(run.relicUseFacts) do if fact.instanceId == startPrimary.instanceId and fact.runYear == run.yearIndex then duplicate = true end end
                if not duplicate then
                    local annual = form.annual or {}
                    local skill = Number(annual.skill)
                    local medicine = Number(annual.medicine)
                    local fact = { instanceId = startPrimary.instanceId, familyId = family.id, formId = form.id, runYear = run.yearIndex, memberId = startPrimary.userId, generation = assert(startMember.generation), jobId = row.jobId, executed = row.executed, paid = row.paid, growth = { skill = skill, medicine = medicine, money = Number(annual.money) } }
                    table.insert(run.relicUseFacts, fact)
                    table.insert(ledger.relicEffects, Copy(fact))
                    State.AddFact(run, "relic", form.name .. "被实际使用，年度效果已结算。", { startPrimary.userId }, { outcome = "relic_use_year", relicInstanceId = startPrimary.instanceId, instanceId = startPrimary.instanceId, runYear = run.yearIndex, jobId = row.jobId, executed = row.executed, paid = row.paid, growth = fact.growth })
                end
            end
        end
    end
end

local function WorkAllowed(run, yearStart, ledger, task)
    local rows = LedgerRows(ledger)
    local ids = task.participantIds or { task.executorId }
    for _, memberId in ipairs(ids) do
        local startMember = Member(yearStart, memberId)
        local currentMember = Member(run, memberId)
        if not startMember or not currentMember or not Alive(startMember) or not Alive(currentMember) or not ActualWork(rows[memberId]) then return false, "参与人本年度没有形成真实执行与支付记录。" end
    end
    ---@type table<string, any>
    local original = Definitions.Action(task.actionId).requirements
    local requirements = {}
    for _, key in ipairs({ "adult", "alive", "stat", "anyStat", "job", "master", "apprentice" }) do requirements[key] = original[key] end
    local reasons = {}
    CheckMemberRequirements(yearStart, { requirements = requirements }, task, nil, nil, reasons, true)
    if #reasons > 0 then return false, table.concat(reasons, "；") end
    return true, rows
end

local function WorkFact(yearStart, task, rows, runYear)
    local work = { runYear = runYear, yearIndex = runYear, memberIds = Copy(task.participantIds), attachedInstanceIds = Copy(task.attachedInstanceIds), jobIds = {}, boundUsers = {}, qualifiedUsers = {}, executed = true }
    for _, memberId in ipairs(task.participantIds or {}) do work.jobIds[tostring(memberId)] = rows[memberId] and rows[memberId].jobId end
    for _, instanceId in ipairs(task.attachedInstanceIds or {}) do
        local instance = RelicState.Find(yearStart, instanceId)
        if instance and instance.userId then
            work.boundUsers[instanceId] = instance.userId
            local user = Member(yearStart, instance.userId)
            work.qualifiedUsers[instanceId] = instance.availability == "usable" and ActualWork(rows[instance.userId]) and RelicState.EligibleUser(yearStart, instance, user) or false
        end
    end
    return work
end

function RelicSystem.Tick(run, profile, yearStart, ledger)
    local checkedRun, checkedProfile, errorMessage = Ensure(run, profile)
    if not checkedRun then return false, errorMessage end
    if type(yearStart) ~= "table" or type(ledger) ~= "table" then return false, "信物年度结算缺少年初快照或年度账本。" end
    if yearStart.yearIndex == nil then return false, "年初快照缺少 yearIndex。" end
    if run.relicSettledYear == run.yearIndex then return true, {} end
    run.relicSettlementYear = run.yearIndex
    ApplyAnnual(run, yearStart, ledger)
    local messages = {}
    local context = MakeContext()
    for _, task in ipairs(List(run.relicTasks)) do
        if task.status == "active" then
            local ok, rowsOrReason = WorkAllowed(run, yearStart, ledger, task)
            if not ok then
                task.status = "paused_requirements"
                task.pauseReason = rowsOrReason
                ReleaseAttachments(run, task)
                table.insert(messages, task.id .. " 已暂停：" .. rowsOrReason)
            else
                task.completedWorkYears = math.tointeger(task.completedWorkYears) or 0
                task.totalWorkYears = math.tointeger(task.totalWorkYears) or 0
                task.completedWorkYears = math.min(task.totalWorkYears, task.completedWorkYears + 1)
                task.remainingWorkYears = task.totalWorkYears - task.completedWorkYears
                table.insert(task.workFacts, WorkFact(yearStart, task, rowsOrReason, run.yearIndex))
                if task.remainingWorkYears <= 0 then
                    local result, message = Outcomes.Complete(context, run, checkedProfile, task)
                    if result == "ready" then
                        task.completedWorkYears = task.totalWorkYears
                        task.remainingWorkYears = 0
                        table.insert(messages, message)
                    elseif result == "settled" then
                        local action = Definitions.Action(task.actionId)
                        if action.claimKey and action.cooldownYears == 0 then ConsumeClaim(run, action.claimKey, task.instanceId) end
                        SettleTask(run, task)
                        AddTaskFact(run, task, message)
                        table.insert(messages, message)
                    else
                        task.status = "paused_requirements"
                        table.insert(messages, message or "任务结果无法结算。")
                    end
                end
            end
        end
    end
    for _, project in pairs(Map(run.relicExternalProjects)) do
        if project.status == "active" then
            local rows, valid = LedgerRows(ledger), true
            for _, id in ipairs(project.participantIds) do if not ActualWork(rows[id]) then valid = false end end
            if valid then table.insert(project.workFacts, WorkFact(yearStart, project, rows, run.yearIndex)) end
        end
    end
    ledger.relicTransactions = {}
    for _, entry in ipairs(run.relicTransactions or {}) do
        if entry.runYear == run.yearIndex then table.insert(ledger.relicTransactions, Copy(entry)) end
    end
    ledger.money, ledger.grain = run.money, run.grain
    ledger.netMoney, ledger.netGrain = run.money - ledger.beforeMoney, run.grain - ledger.beforeGrain
    run.relicSettlementYear = nil
    run.relicSettledYear = run.yearIndex
    return true, messages
end

function RelicSystem.AfterDeaths(run)
    for _, instance in ipairs(List(run.relicInstances)) do
        if instance.userId and not Alive(Member(run, instance.userId)) then instance.userId = nil end
        if instance.custodianId and not Alive(Member(run, instance.custodianId)) then instance.custodianId = nil end
    end
    for _, task in ipairs(List(run.relicTasks)) do
        if IsActiveTask(task) and ((task.executorId and not Alive(Member(run, task.executorId))) or (task.learnerId and not Alive(Member(run, task.learnerId)))) then
            task.status = "paused_actor"
            ReleaseAttachments(run, task)
        end
    end
    return true, "已处理信物使用人与任务参与人的死亡影响。"
end

function RelicSystem.Archive(run)
    run.relicArchived = true
    for _, task in ipairs(List(run.relicTasks)) do
        if IsBlockingTask(task) then task.status = "cancelled"; task.archived = true; task.settledYear = run.yearIndex; ReleaseTaskInstances(run, task) end
    end
    for _, instance in ipairs(List(run.relicInstances)) do if instance.status == "held" then instance.availability = "sealed" end end
    return true, "本局信物任务已归档。"
end

function RelicSystem.OnSuccession(run, oldLeaderId, newLeaderId, term, wasEffective)
    if not term or term.realHandover ~= true or not oldLeaderId or not newLeaderId then return false, "本次交接不满足真实交接条件。" end
    local terms = List(run.leaderTerms)
    for index = 1, math.max(0, #terms - 1) do if terms[index].memberId == newLeaderId then return false, "继任者此前已有任期。" end end
    local rewarded = 0
    local function reward(familyId, amount, key, text)
        local instance = RelicState.Primary(run, familyId)
        local cooldownKey = familyId .. ".succession"
        if not instance or instance.status ~= "held" or instance.availability ~= "usable" or ClaimConsumed(run, key) or CooldownBlocked(run, cooldownKey) then return end
        if not instance.userId or not RelicState.EligibleUser(run, instance, Member(run, instance.userId)) then return end
        run.reputation = Number(run.reputation) + amount
        ConsumeClaim(run, key, instance.instanceId)
        SetCooldown(run, cooldownKey, 3)
        State.AddFact(run, "relic", text, ValidMemberIds(run, { oldLeaderId, newLeaderId, instance.userId }), { outcome = "relic.succession", relicInstanceId = instance.instanceId, oldLeaderId = oldLeaderId, newLeaderId = newLeaderId, realHandover = true, reputation = amount })
        rewarded = rewarded + amount
    end
    local genealogy = RelicState.Primary(run, "genealogy")
    if genealogy and genealogy.tier >= 2 then reward("genealogy", genealogy.tier >= 3 and 5 or 3, "genealogy.succession." .. tostring(newLeaderId), "真实交接完成，族谱为新任族长留下了交接声望。") end
    local jade = RelicState.Primary(run, "jade")
    if jade and jade.tier == 3 and jade.branch == "heirloom" then reward("jade", 2, "jade.succession." .. tostring(newLeaderId), "合璧传家的玉佩见证真实交接，声望增加。") end
    if rewarded > 0 then return true, "真实交接奖励已结算。" end
    return true, "真实交接已记录。"
end

function RelicSystem.MigrationQuote(run, baseCost)
    local base = math.max(0, math.tointeger(Number(baseCost)) or 0)
    local quote = { allowed = true, baseCost = base, cost = base, discount = 0, relicInstanceId = nil, nextAcceptYear = nil }
    local instance = RelicState.Primary(run, "jade")
    if instance and instance.status == "held" and instance.availability == "usable" and instance.tier == 3 and instance.branch == "alliance"
        and instance.userId and RelicState.EligibleUser(run, instance, Member(run, instance.userId)) then
        quote.relicInstanceId = instance.instanceId
        local cooldown = Cooldown(run, "jade.migration")
        if not cooldown or Number(run.yearIndex) >= Number(cooldown.nextAcceptYear) then quote.discount = math.min(8, base); quote.cost = base - quote.discount else quote.nextAcceptYear = cooldown.nextAcceptYear end
    end
    return quote
end

function RelicSystem.RecordMigration(run, quote, placeId)
    if type(quote) ~= "table" or not quote.allowed then return false, "迁居优惠报价无效。" end
    local current = RelicSystem.MigrationQuote(run, quote.baseCost or quote.cost)
    if current.discount ~= quote.discount or current.cost ~= quote.cost then return false, "迁居优惠报价已失效。" end
    if quote.discount <= 0 then return true, "本次迁居没有使用信物优惠。" end
    SetCooldown(run, "jade.migration", 5)
    Transaction(run, "relic_migration_discount", 0, 0, { instanceId = quote.relicInstanceId, discount = quote.discount, label = "玉佩迁居费用减免" })
    State.AddFact(run, "relic", "各执半佩为本次真实迁居减免了银两。", {}, { outcome = "relic.migration_discount", relicInstanceId = quote.relicInstanceId, placeId = placeId, baseCost = quote.baseCost, discount = quote.discount, cost = quote.cost })
    return true, "迁居优惠已记录。"
end

function RelicSystem.RegisterExternalProject(run, projectId, participantIds, attachedInstanceIds, metadata)
    if not RelicState.IsNew(run) or run.ending then return false, "当前家谱无法承接工程。" end
    if type(projectId) ~= "string" or projectId == "" then return false, "外部工程编号无效。" end
    local ids = ValidMemberIds(run, participantIds)
    if #ids == 0 then return false, "外部工程必须有真实参与人。" end
    run.relicExternalProjects = run.relicExternalProjects or {}
    if run.relicExternalProjects[projectId] then return false, "该工程编号已经登记。" end
    local reasons = {}
    CheckAttachments(run, { attachedInstanceIds = attachedInstanceIds or {} }, nil, reasons)
    for _, id in ipairs(ids) do
        if not Adult(Member(run, id)) or MemberTaskCount(run, id) > 0 then table.insert(reasons, "工程参与人需要在世成年且没有其他额外事务。") end
    end
    if #reasons > 0 then return false, table.concat(reasons, "；") end
    run.relicExternalProjects[projectId] = { id = projectId, projectId = projectId, external = true, participantIds = Copy(ids), attachedInstanceIds = Copy(attachedInstanceIds or {}), metadata = Copy(metadata or {}), status = "active", acceptedYear = run.yearIndex, workFacts = {} }
    return true, run.relicExternalProjects[projectId]
end

function RelicSystem.AdvanceExternalProject(run, projectId, yearIndex, participantIds, attachedInstanceIds, outcome)
    local project = Map(run.relicExternalProjects)[projectId]
    if not project then return false, "外部工程尚未登记。" end
    if project.status ~= "active" or run.ending then return false, "该工程当前无法重复结算。" end
    if outcome ~= "success" and outcome ~= "failed" then return false, "外部工程结果无效。" end
    if yearIndex ~= run.yearIndex or #project.workFacts == 0 then return false, "工程尚未完成真实工作年度。" end
    for _, id in ipairs(participantIds or {}) do if not HasId(project.participantIds, id) then return false, "不能在完工后追加参与人。" end end
    for _, id in ipairs(attachedInstanceIds or {}) do if not HasId(project.attachedInstanceIds, id) then return false, "不能在完工后追加信物。" end end
    local participants = project.participantIds
    project.status = outcome
    project.settledYear = yearIndex
    if outcome == "success" then RecordProject(run, project) end
    State.AddFact(run, "relic", "外部工程已记录真实参与与结果。", participants, { outcome = "relic.external_project", projectId = projectId, projectOutcome = outcome, attachedInstanceIds = Copy(project.attachedInstanceIds), yearIndex = yearIndex })
    return true, project
end

return RelicSystem
