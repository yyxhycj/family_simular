local UI = require "urhox-libs/UI"
local State = require "Jiaye.State"
local Data = require "Jiaye.Data"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"
local Defs = require "Jiaye.RelicDefinitions"
local RelicState = require "Jiaye.RelicState"
local RelicSystem = require "Jiaye.RelicSystem"

local View = {}
local C = V7.Colors

local function scrollHeight()
    return math.max(100, UI.GetHeight() * 0.9 - 168)
end

local function closeDetail(app)
    if app.relicDetailModal then app.relicDetailModal:Close() end
end

local STATUS_NAMES = {
    held = "持有", active = "进行中", paused_manual = "已暂停 · 手动", paused_actor = "已暂停 · 执行人变化",
    paused_requirements = "已暂停 · 门槛变化", ready = "已完成待领取", settled = "已结算", cancelled = "已取消",
    usable = "可使用", sealed = "已封存", sold = "已出售",
}
local ROUTE_NAMES = {
    fast = "快速查证", slow = "慢速查证", personal = "亲自递送", entrusted = "托人递送",
    books = "购齐旧书", grain = "送粮助人", silver = "援银", heirloom = "合璧传家", alliance = "各执半佩",
    private = "家传路线", public = "公开刊行", restore = "补入族谱", defer = "暂存线索",
}
local ABILITY_NAMES = { learn = "学识", skill = "手艺", medicine = "医术", trade = "经营", martial = "武艺" }

local function displayValue(value, kind)
    if value == nil then return "" end
    if kind == "status" then return STATUS_NAMES[value] or "当前状态" end
    if kind == "route" or kind == "branch" then return ROUTE_NAMES[value] or "当前路线" end
    if kind == "ability" then return ABILITY_NAMES[value] or "相关能力" end
    return tostring(value)
end

local function member(run, memberId)
    if not memberId then return nil end
    return State.FindMember(run.members or {}, memberId)
end

local function adults(run)
    local result = {}
    for _, item in ipairs(run.members or {}) do
        if item.alive and State.IsAdult(item) then table.insert(result, item) end
    end
    return result
end

local function allLiving(run)
    local result = {}
    for _, item in ipairs(run.members or {}) do
        if item.alive then table.insert(result, item) end
    end
    return result
end

local function memberLabel(item)
    return item and (item.name .. " · " .. tostring(item.age) .. "岁") or "待指定"
end

local function optionsFor(run, values)
    local result = {}
    for _, item in ipairs(values) do table.insert(result, { value = item.id, label = memberLabel(item) }) end
    return result
end

local function formOf(instance)
    return RelicState.Form(instance) or Defs.Form(instance.formId or instance.definitionId) or Defs.LegacyForm(instance.definitionId)
end

local function familyOf(form)
    return form and (Defs.Family(form.familyId) or { id = form.familyId, name = form.familyId }) or { id = "unknown", name = "未分类" }
end

local function instances(run)
    local result = {}
    for _, item in ipairs(run.relicInstances or {}) do
        if item.status ~= "sold" and item.availability ~= "sold" then table.insert(result, item) end
    end
    return result
end

local function findInstance(run, instanceId)
    for _, item in ipairs(run.relicInstances or {}) do
        if item.instanceId == instanceId then return item end
    end
    return nil
end

local function taskOf(run, instance)
    if not instance or not instance.taskId then return nil end
    for _, task in ipairs(run.relicTasks or {}) do
        if task.id == instance.taskId or task.taskId == instance.taskId then return task end
    end
    return nil
end

local function actionList()
    return Defs.Actions or {}
end

local function actionFor(actionId)
    return Defs.Action(actionId)
end

local function button(label, onClick, props)
    props = props or {}
    props.height = math.max(44, props.height or 44)
    props.fontSize = math.max(14, props.fontSize or 15)
    return Visual.Button(label, onClick, props)
end

local function text(value, props)
    return Visual.Text(tostring(value or ""), props or {})
end

local function card(children, props)
    return Visual.Card(children, props or { padding = 12, gap = 8 })
end

local function costText(cost)
    if type(cost) == "string" then return cost end
    cost = cost or {}
    local parts = {}
    if (cost.money or 0) ~= 0 then table.insert(parts, "银 " .. tostring(cost.money) .. " 两") end
    if (cost.grain or 0) ~= 0 then table.insert(parts, "粮 " .. tostring(cost.grain) .. " 石") end
    return #parts > 0 and table.concat(parts, " · ") or "无即时花费"
end

local function previewText(preview)
    if type(preview) == "string" then return preview end
    if type(preview) ~= "table" then return "按当前家谱事实结算。" end
    local parts = {}
    if preview.cost then table.insert(parts, "成本：" .. costText(preview.cost)) end
    if preview.outcome then table.insert(parts, "结果：" .. tostring(preview.outcome)) end
    if preview.result then table.insert(parts, "结果：" .. tostring(preview.result)) end
    if preview.fact then table.insert(parts, "事实：" .. tostring(preview.fact)) end
    return #parts > 0 and table.concat(parts, "；") or "按当前家谱事实结算。"
end

local function quoteText(quote)
    local parts = { "成本 · " .. costText(quote.cost), "执行 · " .. tostring(quote.workYears or 0) .. " 年" }
    if quote.sealsRelic then table.insert(parts, "接受后立即封存，完成升级后恢复使用；暂停仍封存") end
    if quote.preview then table.insert(parts, "结果 · " .. previewText(quote.preview)) end
    return table.concat(parts, "\n")
end

local function actionEvent(action, input)
    if action.familyId == "genealogy" then
        return { type = action.id == "genealogy.invite_branch" and "invite_branch" or "legacy_pending" }, "book"
    end
    if action.familyId == "ruler" then return { type = "relic_resolution" }, "ruler" end
    if action.familyId == "letter" then
        return { type = action.id == "letter.ask_aid" and "community_request" or "relic_resolution" }, "letter"
    end
    if action.familyId == "plan" then return { type = "plan_work" }, "plan" end
    if action.familyId == "jade" then return { type = "jade_search" }, "jade" end
    if action.familyId == "notes" then return { type = "medical_find" }, "notes" end
    return nil, nil
end

local function reasonsText(quote)
    local reasons = quote and quote.reasons or {}
    if #reasons == 0 then return "当前门槛已满足，可以确认。" end
    local shown = {}
    for _, reason in ipairs(reasons) do
        local value = tostring(reason)
        for raw, chinese in pairs(ABILITY_NAMES) do value = string.gsub(value, raw, chinese) end
        for raw, chinese in pairs(ROUTE_NAMES) do value = string.gsub(value, raw, chinese) end
        table.insert(shown, value)
    end
    return "暂不可执行：\n· " .. table.concat(shown, "\n· ")
end

local function taskText(task)
    if not task then return "暂无进行中的行动" end
    local names = {
        paused_manual = "已暂停 · 手动",
        paused_actor = "已暂停 · 执行人变化",
        paused_requirements = "已暂停 · 门槛变化",
        ready = "已完成待领取",
        settled = "已结算",
        cancelled = "已取消",
    }
    local state = names[task.status] or displayValue(task.status, "status") or "进行中"
    local done = task.completedWorkYears or 0
    local total = task.totalWorkYears or task.remainingWorkYears or 0
    return state .. " · " .. tostring(done) .. "/" .. tostring(total) .. " 年"
end

local function effectText(run, instance)
    local form = formOf(instance)
    local user = member(run, instance and instance.userId)
    if not form or not user then return "当前使用者未指定，满足门槛后可绑定。" end
    local primaryId = run.primaryRelics and run.primaryRelics[form.familyId]
    if primaryId ~= instance.instanceId then
        return "当前物件暂未设为主件；主件切换后才会显示它的年度效果。"
    end
    local effect = RelicState.EffectsFor(run, user) or {}
    local source = effect.relicSources and effect.relicSources[form.familyId]
    if not source or source.instanceId ~= instance.instanceId then
        return "当前物件暂未产生年度效果；主件、使用者或资格条件尚未指向这件信物。"
    end
    local parts = {}
    if (source.skill or 0) ~= 0 then table.insert(parts, "手艺 +" .. tostring(source.skill)) end
    if (source.medicine or 0) ~= 0 then table.insert(parts, "医术 +" .. tostring(source.medicine)) end
    if (source.money or 0) ~= 0 then table.insert(parts, "年度银钱 +" .. tostring(source.money)) end
    if #parts == 0 then return "当前形态暂无年度数值效果，成长行动仍可继续。" end
    return table.concat(parts, " · ")
end

local function roleText(run, instance)
    local custodian = member(run, instance.custodianId)
    local user = member(run, instance.userId)
    local task = taskOf(run, instance)
    local executor = member(run, task and task.executorId or instance.executorId)
    return "保管 · " .. memberLabel(custodian) .. "\n使用 · " .. memberLabel(user) .. "\n执行 · " .. memberLabel(executor)
end

local function instanceTitle(instance)
    local form = formOf(instance)
    return form and form.name or tostring(instance.formId or instance.definitionId or "未登记形态")
end

local function lifecycleModal(app, title, detail, action, confirmText, extra)
    local modal = UI.Modal {
        title = title, size = "fullscreen", backgroundColor = C.paperLight,
        borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary,
        closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end,
    }
    local paperChildren = { text(detail, { fontSize = 16, whiteSpace = "normal", lineHeight = 1.55 }) }
    if extra then table.insert(paperChildren, extra) end
    modal:AddContent(UI.ScrollView { height = scrollHeight(), children = { Visual.Paper(paperChildren, { padding = 14, gap = 10 }) } })
    local submitted = false
    modal:SetFooter(UI.Row { gap = 8, children = {
        button("返回", function() modal:Close() end, { flex = 1, role = "secondary" }),
        button(confirmText or "确认", function()
            if submitted then return end
            submitted = true
            if app:RunAction(action) then modal:Close(); closeDetail(app) else submitted = false end
        end, { flex = 1 }),
    } })
    modal:Open()
end

local function selectMember(run, label, values, selectedId, onChange, allowEmpty)
    local current = selectedId or (allowEmpty and "" or (values[1] and values[1].id))
    local function selectedLabel(value)
        return value == "" and "家中保管/暂不使用" or memberLabel(member(run, value))
    end
    local selectOptions = optionsFor(run, values)
    if allowEmpty then table.insert(selectOptions, 1, { value = "", label = "家中保管/暂不使用" }) end
    local caption = text(label .. " · " .. selectedLabel(current), { fontSize = 14, fontColor = C.secondary })
    local dropdown = UI.Dropdown {
        options = selectOptions, value = current, height = 44, fontSize = V7.Font(15),
        triggerBgColor = C.paperLight, borderColor = C.rule, openBorderColor = C.gold,
        onChange = function(_, value)
            current = value
            caption:SetText(label .. " · " .. selectedLabel(value))
            onChange(value)
        end,
    }
    return UI.Panel { gap = 6, children = { caption, dropdown } }, function() return current end
end

local function sortedKeys(map)
    local keys = {}
    for key, _ in pairs(map or {}) do table.insert(keys, key) end
    table.sort(keys)
    return keys
end

local function routeLabel(key, route, branch)
    local label = ROUTE_NAMES[key] or "当前路线"
    if type(branch) == "string" then label = ROUTE_NAMES[branch] or branch end
    if type(branch) == "table" then
        label = branch.label or branch.name or branch.outcome
        if not label and branch.resultFormId then
            local resultForm = Defs.Form(branch.resultFormId)
            label = resultForm and ("进入 · " .. resultForm.name) or nil
        end
        label = label or key
    end
    if type(route) == "table" then
        local routeName = route.label or route.name
        if routeName then label = tostring(label) .. " · " .. tostring(routeName) end
    end
    return label
end

local function routeOptions(action, input)
    local routes = action.routes or {}
    local branches = action.branches or {}
    local routeMap = {}
    for _, key in ipairs(sortedKeys(routes)) do routeMap[key] = true end
    for _, key in ipairs(sortedKeys(branches)) do routeMap[key] = true end
    local values = {}
    for _, key in ipairs(sortedKeys(routeMap)) do
        table.insert(values, { value = key, label = routeLabel(key, routes[key], branches[key]) })
    end
    if #values == 0 then return nil end
    local selected = input.route or input.branch or values[1].value
    return values, selected
end

local function apprenticeMembers(run, masterId, minimumAge)
    local result = {}
    for _, item in ipairs(allLiving(run)) do
        if item.id ~= masterId and (item.age or 0) >= (minimumAge or 0) then table.insert(result, item) end
    end
    return result
end

local function sameFamilyInstances(run, familyId)
    local result = {}
    for _, item in ipairs(run.relicInstances or {}) do
        local form = formOf(item)
        if form and form.familyId == familyId and item.status ~= "sold" and item.availability ~= "sold" then table.insert(result, item) end
    end
    return result
end

local function instanceOptions(run, values)
    local result = {}
    for _, item in ipairs(values) do table.insert(result, { value = item.instanceId, label = instanceTitle(item) .. " · " .. displayValue(item.status or "held", "status") }) end
    return result
end

local function selectionOptions(action, run, input, onChanged)
    input = input or {}
    local children = {}
    local requirements = action.requirements or {}
    if input.familyId then
        local sameFamily = sameFamilyInstances(run, input.familyId)
        if #sameFamily > 0 then
            local primary = RelicState.Primary(run, input.familyId)
            local selected = input.instanceId or (primary and primary.instanceId) or sameFamily[1].instanceId
            input.instanceId = selected
            table.insert(children, UI.Dropdown {
                options = instanceOptions(run, sameFamily), value = selected, height = 44, fontSize = V7.Font(15),
                triggerBgColor = C.paperLight, borderColor = C.rule, openBorderColor = C.gold,
                onChange = function(_, value) input.instanceId = value; onChanged() end,
            })
        else
            table.insert(children, text("本家成长线尚未有可用实例；门槛页仍会保留，取得后可从藏阁继续。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" }))
        end
    end
    local adultMembers = adults(run)
    local needsExecutor = input.taskId ~= nil or requirements.adult == true or requirements.currentUser ~= nil or requirements.master ~= nil
    if needsExecutor then
        local executorLabel = requirements.master and "传艺人" or (requirements.currentUser and "使用者" or "执行人")
        local panel, getValue = selectMember(run, executorLabel, adultMembers, input.executorId, function(value)
            input.executorId = value
            onChanged()
        end)
        input.executorId = input.executorId or getValue()
        table.insert(children, panel)
        if action.familyId == "plan" then
            local selected = {}
            for _, id in ipairs(input.attachedInstanceIds or {}) do selected[id] = true end
            local rulers = {}
            for _, relic in ipairs(run.relicInstances or {}) do
                local relicForm = formOf(relic)
                if relicForm and relicForm.familyId == "ruler" and relic.status == "held" and (relic.availability or "usable") == "usable" and relic.userId == input.executorId then
                    table.insert(rulers, relic)
                end
            end
            if #rulers > 0 then
                local mountPanel = UI.Panel { gap = 5 }
                mountPanel:AddChild(text("可挂载的木尺（同一办理人）", { fontSize = 14, fontWeight = "bold" }))
                for _, ruler in ipairs(rulers) do
                    local rulerId = ruler.instanceId
                    mountPanel:AddChild(UI.Checkbox {
                        label = instanceTitle(ruler), checked = selected[rulerId] == true,
                        onChange = function(_, checked)
                            selected[rulerId] = checked
                            input.attachedInstanceIds = {}
                            for id, enabled in pairs(selected) do if enabled then table.insert(input.attachedInstanceIds, id) end end
                            onChanged()
                        end,
                    })
                end
                table.insert(children, mountPanel)
            end
        end
    end
    if requirements.apprentice then
        local apprenticeRequirement = requirements.apprentice
        local minimumAge = type(apprenticeRequirement) == "table" and apprenticeRequirement.minAge or 0
        local panel, getValue = selectMember(run, "学徒", apprenticeMembers(run, input.executorId, minimumAge), input.learnerId, function(value)
            input.learnerId = value
            onChanged()
        end)
        input.learnerId = input.learnerId or getValue()
        table.insert(children, panel)
    end
    local values, selected = routeOptions(action, input)
    if values then
        input.route = action.routes and selected or nil
        input.branch = action.branches and selected or nil
        table.insert(children, UI.Dropdown {
            options = values, value = selected, height = 44, fontSize = V7.Font(15),
            triggerBgColor = C.paperLight, borderColor = C.rule, openBorderColor = C.gold,
            onChange = function(_, value)
                input.route = action.routes and value or nil
                input.branch = action.branches and value or nil
                onChanged()
            end,
        })
    end
    return children
end

function View.OpenAction(app, actionId, sourceInput)
    local action = actionFor(actionId)
    if not action then
        local picker = UI.Modal {
            title = "选择行动", size = "fullscreen", backgroundColor = C.paperLight,
            borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary,
            closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end,
        }
        local pickerBody = UI.Panel { gap = 8 }
        local familyId = sourceInput and sourceInput.familyId
        for _, item in ipairs(actionList()) do
            if not familyId or item.familyId == familyId then pickerBody:AddChild(button(item.name or item.id, function()
                picker:Close()
                local primary = RelicState.Primary(app.run, item.familyId)
                local nextInput = {}
                for key, value in pairs(sourceInput or {}) do nextInput[key] = value end
                nextInput.familyId = item.familyId
                nextInput.instanceId = nextInput.instanceId or (primary and primary.instanceId)
                View.OpenAction(app, item.id, nextInput)
            end, { width = "100%", role = "secondary", textAlign = "left" })) end
        end
        picker:AddContent(UI.ScrollView { height = scrollHeight(), children = { pickerBody } })
        picker:SetFooter(button("返回", function() picker:Close() end, { width = "100%", role = "secondary" }))
        picker:Open()
        return
    end
    local input = {}
    for key, value in pairs(sourceInput or {}) do input[key] = value end
    local modal = UI.Modal {
        title = "行动 · " .. tostring(action.name or actionId), size = "fullscreen", backgroundColor = C.paperLight,
        borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary,
        closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end,
    }
    local body = UI.Panel { gap = 10 }
    local quoteLabel = text("正在核对门槛…", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 })
    local reasonLabel = text("", { fontSize = 14, fontColor = C.danger, whiteSpace = "normal", lineHeight = 1.5 })
    local confirm
    local function refresh()
        local quote = RelicSystem.Quote(app.run, actionId, input)
        quoteLabel:SetText(quoteText(quote))
        reasonLabel:SetText(reasonsText(quote))
        if confirm then confirm:SetDisabled(not quote.allowed) end
        input._quote = quote
    end
    local optionPanel = UI.Panel { gap = 8 }
    local function rebuildOptions()
        optionPanel:ClearChildren()
        local children = selectionOptions(action, app.run, input, rebuildOptions)
        for _, child in ipairs(children) do optionPanel:AddChild(child) end
        refresh()
    end
    modal:AddContent(UI.ScrollView { height = scrollHeight(), children = { body } })
    local event, eventRelicId = actionEvent(action, input)
    local actionChildren = {
        text(action.name or actionId, { fontSize = 22, fontWeight = "bold" }),
        text(previewText(action.preview or action.description), { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }),
    }
    if event then table.insert(actionChildren, Visual.EventImage(event, eventRelicId, { height = 132 })) end
    table.insert(actionChildren, optionPanel)
    table.insert(actionChildren, text("预估", { fontSize = 16, fontWeight = "bold", marginTop = 4 }))
    table.insert(actionChildren, quoteLabel)
    table.insert(actionChildren, reasonLabel)
    body:AddChild(Visual.Paper(actionChildren, { padding = 14, gap = 10 }))
    modal:SetFooter(UI.Row { gap = 8, children = {
        button("返回", function() modal:Close() end, { flex = 1, role = "secondary" }),
        (function()
            confirm = button("确认行动", function()
                local quote = input._quote or RelicSystem.Quote(app.run, actionId, input)
                if not quote.allowed then return end
                if app:RunAction(function(run, profile) return RelicSystem.Start(run, profile, actionId, input) end) then modal:Close(); closeDetail(app) end
            end, { flex = 1 })
            return confirm
        end)(),
    } })
    rebuildOptions()
    modal:Open()
end

local managementActions

local function relatedEvidence(value, instanceId)
    if type(value) ~= "table" then return false end
    if value.instanceId == instanceId or value.relicInstanceId == instanceId or value.sourceInstanceId == instanceId then return true end
    for _, attachedId in ipairs(value.attachedInstanceIds or {}) do if attachedId == instanceId then return true end end
    local source = value.source
    return type(source) == "table" and (source.instanceId == instanceId or source.relicInstanceId == instanceId or source.sourceInstanceId == instanceId)
end

local function evidenceText(run, value)
    local parts = {}
    local year = value.runYear or value.settledYear
    if value.year then table.insert(parts, "大晟历" .. tostring(value.year) .. "年")
    elseif year then table.insert(parts, "第" .. tostring(year) .. "个结算年度") end
    if value.text then table.insert(parts, value.text) end
    if value.memberId then
        local actor = member(run, value.memberId)
        table.insert(parts, assert(actor).name)
    end
    if value.generation then table.insert(parts, "第" .. tostring(value.generation) .. "代") end
    if value.jobId then table.insert(parts, assert(Data.Jobs[value.jobId]).name) end
    if value.projectId then table.insert(parts, "工程完成") end
    if value.workYears then table.insert(parts, "实际参与年度 " .. table.concat(value.workYears, "、")) end
    if value.participantIds then
        local names = {}
        for _, id in ipairs(value.participantIds) do table.insert(names, assert(member(run, id)).name) end
        table.insert(parts, "参与人 " .. table.concat(names, "、"))
    end
    return table.concat(parts, " · ")
end

local function evidenceLines(run, instance)
    local id = instance.instanceId
    local history = {}
    local useFacts = {}
    local projectFacts = {}
    for _, fact in ipairs(run.facts or {}) do
        if relatedEvidence(fact, id) then
            table.insert(history, evidenceText(run, fact))
            if fact.factsSnapshot then
                table.insert(history, "编修时封存 " .. tostring(#fact.factsSnapshot) .. " 条族史：")
                for _, saved in ipairs(fact.factsSnapshot) do table.insert(history, "  " .. evidenceText(run, saved)) end
            end
        end
    end
    for _, fact in ipairs(run.relicUseFacts or {}) do if relatedEvidence(fact, id) then table.insert(useFacts, evidenceText(run, fact)) end end
    for _, fact in ipairs(run.relicProjectFacts or {}) do if relatedEvidence(fact, id) then table.insert(projectFacts, evidenceText(run, fact)) end end
    local candidate = {}
    local claim = run.relicClaims and run.relicClaims["genealogy.branch_candidate"]
    if formOf(instance).familyId == "genealogy" and claim and claim.candidate then
        local person = claim.candidate
        table.insert(candidate, person.name .. " · " .. person.sex .. " · 第" .. tostring(person.generation) .. "代")
        table.insert(candidate, "已经营" .. tostring(person.discoveredRunYear) .. "年时发现，当时" .. tostring(person.ageAtDiscovery) .. "岁。" .. person.generationEvidence)
    end
    return history, useFacts, projectFacts, candidate
end

local function detailContent(app, instance, tab, openTab)
    local run = app.run
    local form = formOf(instance)
    local family = familyOf(form)
    local task = taskOf(run, instance)
    local children = {
        UI.Row { gap = 10, alignItems = "center", children = {
            Visual.Relic(form and form.id or instance.definitionId, 82),
            UI.Panel { flex = 1, minWidth = 0, gap = 4, children = {
                text(instanceTitle(instance), { fontSize = 22, fontWeight = "bold" }),
                text(family.name .. " · 第 " .. tostring(form and form.tier or instance.tier or 1) .. " 阶 · " .. displayValue(instance.status or "held", "status"), { fontSize = 13, fontColor = C.secondary }),
                Visual.GetArtVersion() ~= "ink_v2_review" and form and form.tier and form.tier > 1 and text("美术 · 临时复用基础图", { fontSize = 12, fontColor = C.gold, whiteSpace = "normal" }) or UI.Panel { height = 0 },
            } },
        } },
        UI.Row { gap = 5, children = {
            button("作用", function() openTab("effect") end, { flex = 1, role = tab == "effect" and "primary" or "secondary" }),
            button("成长", function() openTab("growth") end, { flex = 1, role = tab == "growth" and "primary" or "secondary" }),
            button("经历", function() openTab("history") end, { flex = 1, role = tab == "history" and "primary" or "secondary" }),
        } },
    }
    if tab == "effect" then
        table.insert(children, card({
            text("当前效果", { fontSize = 18, fontWeight = "bold" }),
            text(effectText(run, instance), { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }),
            text("角色关系", { fontSize = 16, fontWeight = "bold", marginTop = 6 }),
            text(roleText(run, instance), { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 }),
            text("主件 · " .. ((RelicState.Primary(run, family.id) or {}).instanceId == instance.instanceId and "当前主件" or "当前未设为主件"), { fontSize = 14, fontColor = C.secondary }),
            UI.Panel { gap = 7, children = managementActions and managementActions(app, instance) or {} },
        }))
    elseif tab == "growth" then
        table.insert(children, card({
            text("成长状态", { fontSize = 18, fontWeight = "bold" }),
            text(taskText(task), { fontSize = 15, whiteSpace = "normal" }),
            text(form and form.description or "形态说明待补充。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 }),
            text("升级、使用、冷却和领取均以当前本局事实核对；暂停会保留已写入进度。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 }),
        }))
    else
        local history, useFacts, projectFacts, candidate = evidenceLines(run, instance)
        local evidence = {
            text("事实引用", { fontSize = 16, fontWeight = "bold" }),
        }
        for _, line in ipairs(history) do table.insert(evidence, text(line, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 })) end
        if #candidate > 0 then
            table.insert(evidence, text("固定旁支候选", { fontSize = 16, fontWeight = "bold", marginTop = 5 }))
            for _, line in ipairs(candidate) do table.insert(evidence, text(line, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" })) end
        end
        table.insert(evidence, text("实际使用事实", { fontSize = 16, fontWeight = "bold", marginTop = 5 }))
        if #useFacts == 0 then table.insert(evidence, text("尚无已结算的实际使用事实。", { fontSize = 13, fontColor = C.secondary })) end
        for _, line in ipairs(useFacts) do table.insert(evidence, text(line, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 })) end
        table.insert(evidence, text("项目事实", { fontSize = 16, fontWeight = "bold", marginTop = 5 }))
        if #projectFacts == 0 then table.insert(evidence, text("尚无已绑定的项目事实。", { fontSize = 13, fontColor = C.secondary })) end
        for _, line in ipairs(projectFacts) do table.insert(evidence, text(line, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 })) end
        table.insert(children, card({
            text("族史快照", { fontSize = 18, fontWeight = "bold" }),
            text("来源 · " .. (instance.source == "opening" and "开局带入" or tostring(instance.source or "本局开局收藏")), { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal" }),
            text("首次获得 · " .. (instance.acquiredRunYear == 0 and "开局时" or instance.acquiredRunYear and "已经营" .. tostring(instance.acquiredRunYear) .. "年时" or "日期未记录"), { fontSize = 14, fontColor = C.secondary }),
            UI.Panel { gap = 5, children = evidence },
            text("此处显示已写入家谱的事实、实际使用和项目依据；后续证明必须在行动接受时绑定。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 }),
        }))
    end
    return children
end

function View.Open(app, instanceId)
    local instance = findInstance(app.run, instanceId)
    if not instance then app:Notify("这件信物已不在当前家谱中。", "warning"); return end
    closeDetail(app)
    local modal = UI.Modal {
        title = "藏阁 · " .. instanceTitle(instance), size = "fullscreen", backgroundColor = C.paperLight,
        borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary,
        closeOnOverlay = true, onClose = function(selfModal)
            if app.relicDetailModal == selfModal then app.relicDetailModal = nil end
            selfModal:Destroy()
        end,
    }
    app.relicDetailModal = modal
    local activeTab = "effect"
    local body = UI.Panel { gap = 10 }
    local currentInstance = instance
    local function render()
        currentInstance = findInstance(app.run, instanceId)
        if not currentInstance then modal:Close(); return end
        body:ClearChildren()
        for _, child in ipairs(detailContent(app, currentInstance, activeTab, function(nextTab) activeTab = nextTab; render() end)) do body:AddChild(child) end
        local task = taskOf(app.run, currentInstance)
        if task and task.status == "ready" then
            body:AddChild(button("继续处理已完成行动", function()
                View.OpenAction(app, task.readyActionId, { instanceId = currentInstance.instanceId, familyId = formOf(currentInstance).familyId, taskId = task.id, route = task.route, branch = task.branch })
            end, { height = 46 }))
        end
        body:AddChild(button("选择本家行动", function() View.OpenAction(app, nil, { instanceId = currentInstance.instanceId, familyId = formOf(currentInstance).familyId }) end, { height = 46 }))
    end
    modal:AddContent(UI.ScrollView { height = scrollHeight(), children = { body } })
    modal:SetFooter(UI.Row { gap = 8, children = {
        button("关闭", function() modal:Close() end, { flex = 1, role = "secondary" }),
        button("返回藏阁", function() modal:Close() end, { flex = 1 }),
    } })
    render()
    modal:Open()
end

local function resumeTaskModal(app, instance, task)
    local action = actionFor(task.actionId) or { requirements = {} }
    local requirements = action.requirements or {}
    local input = { instanceId = instance.instanceId, executorId = task.executorId, learnerId = task.learnerId }
    local panels = {}
    if requirements.adult or requirements.currentUser or requirements.master then
        local panel, getValue = selectMember(app.run, requirements.master and "传艺人" or "执行人", adults(app.run), input.executorId, function(value) input.executorId = value end)
        input.executorId = input.executorId or getValue()
        table.insert(panels, panel)
    end
    if requirements.apprentice then
        local minimumAge = type(requirements.apprentice) == "table" and requirements.apprentice.minAge or 0
        local panel, getValue = selectMember(app.run, "学徒", apprenticeMembers(app.run, input.executorId, minimumAge), input.learnerId, function(value) input.learnerId = value end)
        input.learnerId = input.learnerId or getValue()
        table.insert(panels, panel)
    end
    lifecycleModal(app, "恢复行动 · " .. instanceTitle(instance), "恢复前可以更换执行人和学徒。原任务进度保留，未完成时继续占用信物；暂停期间不退款。", function(candidate)
        return RelicSystem.Resume(candidate, task.id, input)
    end, "确认恢复", UI.Panel { gap = 8, children = panels })
end

managementActions = function(app, instance)
    local actions = {}
    local run = app.run
    local function assignPerson(kind)
        local candidates = {}
        if kind == "user" then
            for _, candidate in ipairs(allLiving(run)) do
                local eligible = RelicState.EligibleUser(run, instance, candidate)
                if eligible then table.insert(candidates, candidate) end
            end
        else
            candidates = adults(run)
        end
        local label = kind == "user" and "使用者" or "保管人"
        local currentId = kind == "user" and instance.userId or instance.custodianId
        local panel, getValue = selectMember(run, label, candidates, currentId, function() end, kind == "user" or kind == "custodian")
        lifecycleModal(app, "更换" .. label, "使用者、保管人和执行人彼此独立。确认后只更新当前绑定，不会改写已经封存的族史快照。", function(candidate)
            local memberId = getValue()
            if kind == "user" then return RelicSystem.AssignUser(candidate, instance.instanceId, memberId ~= "" and memberId or nil) end
            return RelicSystem.AssignCustodian(candidate, instance.instanceId, memberId ~= "" and memberId or nil)
        end, "确认绑定", panel)
    end
    table.insert(actions, button("更换使用者", function() assignPerson("user") end, { role = "secondary" }))
    table.insert(actions, button("更换保管人", function() assignPerson("custodian") end, { role = "secondary" }))
    table.insert(actions, button("设为主件", function()
        lifecycleModal(app, "设为主件 · " .. instanceTitle(instance), "同一条成长线只保留一个主件。切换主件会影响后续年度效果来源，已经写入家史的事实保持不变。", function(candidate)
            return RelicSystem.SetPrimary(candidate, instance.instanceId)
        end, "确认切换")
    end, { role = "secondary" }))
    local task = taskOf(run, instance)
    if task and (task.status == "paused_manual" or task.status == "paused_actor" or task.status == "paused_requirements") then
        table.insert(actions, button("恢复行动", function()
            resumeTaskModal(app, instance, task)
        end, { role = "secondary" }))
    elseif task and task.status == "ready" then
        table.insert(actions, button("确认领取", function()
            View.OpenAction(app, task.readyActionId, { instanceId = instance.instanceId, familyId = formOf(instance).familyId, taskId = task.id, route = task.route, branch = task.branch })
        end, { role = "secondary" }))
    elseif task and task.status ~= "settled" and task.status ~= "cancelled" then
        table.insert(actions, button("暂停行动", function()
            lifecycleModal(app, "暂停行动", "暂停会释放执行人和参与人，信物保留未完成进度；之后可以从藏阁恢复。", function(candidate)
                return RelicSystem.Pause(candidate, task.id)
            end, "确认暂停")
        end, { role = "secondary" }))
    end
    if task and task.status ~= "settled" and task.status ~= "cancelled" and task.status ~= "ready" then
        table.insert(actions, button("取消行动", function()
            lifecycleModal(app, "取消行动", "取消会释放执行人和参与人，已支付成本不退款，未领取结果不会写入奖励。", function(candidate)
                return RelicSystem.Cancel(candidate, task.id)
            end, "确认取消")
        end, { role = "danger" }))
    end
    table.insert(actions, button("出售信物", function()
        local form = formOf(instance)
        lifecycleModal(app, "确认出售 · " .. instanceTitle(instance), "出售后本局物件与未完成行动不可恢复，当前形态的年度效果停止。已写入家史的事实、收藏资格与曾经获得记录继续保留。\n实际收入：" .. tostring(form and form.saleSilver or 0) .. " 两。\n取消中的未完成行动不退已支付费用。", function(candidate)
            return RelicSystem.Sell(candidate, instance.instanceId)
        end, "确认出售")
    end, { role = "danger" }))
    return actions
end

local function instanceCard(app, instance)
    local form = formOf(instance)
    local family = familyOf(form)
    local task = taskOf(app.run, instance)
    local children = {
        UI.Row { gap = 10, alignItems = "center", children = {
                    Visual.Relic(form and form.id or instance.definitionId, 70),
            UI.Panel { flex = 1, minWidth = 0, gap = 4, children = {
                text(instanceTitle(instance), { fontSize = 19, fontWeight = "bold" }),
                text(family.name .. " · 第 " .. tostring(form and form.tier or instance.tier or 1) .. " 阶", { fontSize = 13, fontColor = C.secondary }),
                text("使用 · " .. memberLabel(member(app.run, instance.userId)) .. "\n" .. taskText(task), { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 }),
            } },
        } },
        text("效果 · " .. effectText(app.run, instance), { fontSize = 14, whiteSpace = "normal", lineHeight = 1.4 }),
        UI.Row { gap = 7, children = {
            button("查看详情", function() View.Open(app, instance.instanceId) end, { flex = 1 }),
            button("管理", function() View.Open(app, instance.instanceId) end, { flex = 1, role = "secondary" }),
        } },
    }
    return card(children, { padding = 10, gap = 8, borderColor = C.gold })
end

local function actionCard(app, action)
    local preview = previewText(action.preview or action.description)
    local primary = RelicState.Primary(app.run, action.familyId)
    return card({
        UI.Row { gap = 8, alignItems = "center", children = {
            text(action.name or action.id, { fontSize = 16, fontWeight = "bold", flex = 1 }),
            text("行动", { fontSize = 12, fontColor = C.secondary, backgroundColor = C.selected, paddingHorizontal = 7, paddingVertical = 3, borderRadius = 3 }),
        } },
        text(preview, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 }),
        button("查看门槛与行动", function()
            View.OpenAction(app, action.id, { familyId = action.familyId, instanceId = primary and primary.instanceId })
        end, { height = 44, role = "secondary" }),
    }, { padding = 10, gap = 7, backgroundColor = C.paper })
end

local function openFormCatalog(app)
    local modal = UI.Modal {
        title = "信物图鉴 · 20 种形态", size = "fullscreen", backgroundColor = C.paperLight,
        borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary,
        closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end,
    }
    local content = UI.Panel { gap = 8 }
    for _, family in ipairs(Defs.Families or {}) do
        content:AddChild(text(family.name or family.id, { fontSize = 18, fontWeight = "bold", marginTop = 5 }))
        for _, form in ipairs(Defs.Forms or {}) do
            if form.familyId == family.id then
                content:AddChild(card({
                    UI.Row { gap = 8, alignItems = "center", children = {
                        Visual.Relic(form.id, 50),
                        UI.Panel { flex = 1, minWidth = 0, gap = 3, children = {
                            text(form.name or form.id, { fontSize = 15, fontWeight = "bold" }),
                            text("第 " .. tostring(form.tier) .. " 阶 · " .. (form.branch and displayValue(form.branch, "branch") or "固定形态"), { fontSize = 12, fontColor = C.secondary }),
                        } },
                    } },
                    text(form.description or "形态说明待行动解锁。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.35 }),
                }, { padding = 9, gap = 6, backgroundColor = C.paper }))
            end
        end
    end
    modal:AddContent(UI.ScrollView { height = scrollHeight(), children = { content } })
    modal:SetFooter(button("返回", function() modal:Close() end, { width = "100%", role = "secondary" }))
    modal:Open()
end

function View.Build(app)
    local run = app.run
    local children = {
        Visual.Decor("branch_line", { width = "100%", height = 12, opacity = 0.42, pointerEvents = "none" }),
        text("本局藏阁", { fontSize = 22, fontWeight = "bold" }),
        text("20 种形态沿六条成长线记录。保管、使用、执行彼此独立；每次行动都会先显示成本、回报和门槛。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 }),
        UI.Row { gap = 8, children = {
            button("20 种形态图鉴", function() openFormCatalog(app) end, { flex = 1, role = "secondary" }),
            button("27 项行动", function() View.OpenAction(app, nil, {}) end, { flex = 1, role = "secondary" }),
        } },
    }
    local actual = instances(run)
    for _, instance in ipairs(actual) do table.insert(children, instanceCard(app, instance)) end
    if #actual == 0 then table.insert(children, card({ text("本局尚未带入信物。", { fontSize = 15, fontColor = C.secondary }), text("开局收藏或本局故事会把可用形态写入藏阁。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" }) })) end
    return UI.Panel { gap = 10, paddingBottom = 14, children = children }
end

return View
