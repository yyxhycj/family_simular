local Definitions = require "Jiaye.RelicDefinitions"

local Validation = {}

local function Integer(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end

function Validation.Profile(profile)
    if profile.unlockedRelicForms == nil then return true end
    if type(profile.unlockedRelicForms) ~= "table" then return false, "信物形态收藏结构无效。" end
    for formId, unlocked in pairs(profile.unlockedRelicForms) do
        if not Definitions.Form(formId) or type(unlocked) ~= "boolean" then return false, "信物形态收藏包含未知引用。" end
    end
    return true
end

function Validation.Draft(draft, profile)
    local issues, families, members = {}, {}, {}
    for _, member in ipairs(draft.members or {}) do members[member.id] = true end
    if type(draft.selectedRelicFormIds) ~= "table" or type(draft.relicUsers) ~= "table" then
        return { "信物形态选择或使用者配置无效。" }
    end
    for _, formId in ipairs(draft.selectedRelicFormIds) do
        local form = Definitions.Form(formId)
        if not form then
            table.insert(issues, "信物形态不存在。")
        else
            if families[form.familyId] then table.insert(issues, "同一条成长线只能带入一件信物。") end
            families[form.familyId] = true
            if not (profile.unlockedRelicForms or {})[formId] then table.insert(issues, "尚未解锁形态：" .. form.name) end
            local userId = draft.relicUsers[formId]
            if userId and not members[userId] then table.insert(issues, "信物使用者引用无效。") end
        end
    end
    return issues
end

local TASK_STATES = {
    active = true, paused_manual = true, paused_actor = true, paused_requirements = true,
    ready = true, settled = true, cancelled = true,
}

function Validation.Run(run, memberIds, relicIds)
    if run.relicRulesVersion == nil then return true end
    if run.relicRulesVersion ~= Definitions.VERSION then return false, "运行家谱的信物规则版本未知。" end
    if run.openingSnapshot.relicRulesVersion ~= Definitions.VERSION then return false, "信物规则与开局快照不一致。" end
    for _, key in ipairs({ "relicTasks", "relicClaims", "relicCooldowns", "primaryRelics", "relicUseFacts", "relicProjectFacts" }) do
        if type(run[key]) ~= "table" then return false, "信物记录缺少字段：" .. key end
    end
    local instances, tasks = {}, {}
    for _, relic in ipairs(run.relicInstances) do
        local form = Definitions.Form(relic.formId)
        if not form or relic.rulesVersion ~= Definitions.VERSION or relic.relicFamilyId ~= form.familyId
            or relic.tier ~= form.tier or relic.branch ~= form.branch or relic.definitionId ~= form.legacyId
            or (relic.availability ~= "usable" and relic.availability ~= "sealed")
            or (relic.userId and not memberIds[relic.userId]) then
            return false, "信物实例的形态、版本或使用者无效。"
        end
        instances[relic.instanceId] = relic
    end
    for _, task in ipairs(run.relicTasks) do
        if type(task) ~= "table" or type(task.id) ~= "string" or tasks[task.id] or not Definitions.Action(task.actionId)
            or not relicIds[task.instanceId] or not TASK_STATES[task.status]
            or (task.executorId and not memberIds[task.executorId])
            or not Integer(task.completedWorkYears) or not Integer(task.totalWorkYears)
            or task.completedWorkYears > task.totalWorkYears then
            return false, "信物任务结构或进度无效。"
        end
        tasks[task.id] = task
        for _, memberId in ipairs(task.participantIds or {}) do
            if not memberIds[memberId] then return false, "信物任务参与人引用无效。" end
        end
        for _, instanceId in ipairs(task.attachedInstanceIds or {}) do
            if not relicIds[instanceId] then return false, "信物任务所附物件引用无效。" end
        end
    end
    for _, relic in ipairs(run.relicInstances) do
        if relic.taskId then
            local task = tasks[relic.taskId]
            local linked = task and task.instanceId == relic.instanceId
            for _, id in ipairs(task and task.attachedInstanceIds or {}) do
                if id == relic.instanceId then linked = true end
            end
            if not linked then return false, "信物与任务的关联无效。" end
        end
    end
    for familyId, instanceId in pairs(run.primaryRelics) do
        local relic = instances[instanceId]
        if not Definitions.Family(familyId) or not relic or relic.relicFamilyId ~= familyId then return false, "信物主件引用无效。" end
    end
    for _, fact in ipairs(run.relicUseFacts) do
        if type(fact) ~= "table" then return false, "实际使用记录结构无效。" end
    end
    for _, fact in ipairs(run.relicProjectFacts) do
        if type(fact) ~= "table" then return false, "实际项目记录结构无效。" end
    end
    return true
end

return Validation
