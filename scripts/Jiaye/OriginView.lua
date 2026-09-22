local UI = require "urhox-libs/UI"
local State = require "Jiaye.State"
local Data = require "Jiaye.Data"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"
local RelicState = require "Jiaye.RelicState"
local RelicDefinitions = require "Jiaye.RelicDefinitions"
local OriginSystem = require "Jiaye.OriginSystem"
local ModalLayout = require "Jiaye.ModalLayout"

local View = {}
local C = V7.Colors

local function text(value, props)
    return Visual.Text(tostring(value or ""), props or {})
end

local function button(label, onClick, props)
    props = props or {}
    props.height = math.max(44, props.height or 44)
    props.fontSize = math.max(14, props.fontSize or 15)
    return Visual.Button(label, onClick, props)
end

local function card(children, props)
    return Visual.Card(children, props or { padding = 12, gap = 8 })
end

local function scrollHeight()
    return 270
end

local function livingMembers(run)
    local members = {}
    for _, member in ipairs(run.members or {}) do
        if member.alive then table.insert(members, member) end
    end
    return members
end

local function memberLabel(member)
    if not member then return "未指定" end
    local job = Data.Jobs[member.jobId]
    return member.name .. " · " .. tostring(member.age or "?") .. "岁 · " .. (job and job.name or "暂无安排")
end

local function costText(cost)
    local parts = {}
    if (cost and cost.money or 0) ~= 0 then table.insert(parts, "银 " .. tostring(cost.money) .. " 两") end
    if (cost and cost.grain or 0) ~= 0 then table.insert(parts, "粮 " .. tostring(cost.grain) .. " 石") end
    return #parts > 0 and table.concat(parts, " · ") or "无即时花费"
end

local function chanceText(value)
    if value == nil then return nil end
    local percent = value <= 1 and value * 100 or value
    return string.format("成功率 %.0f%%", percent)
end

local function quoteText(quote)
    local parts = { "费用 · " .. costText(quote.cost), "工作 · " .. tostring(quote.workYears or 0) .. " 个有效年度" }
    local chance = chanceText(quote.successChance)
    if chance then table.insert(parts, chance) end
    return table.concat(parts, "\n")
end

local function reasonsText(quote)
    if quote.allowed then return "当前条件已满足，可以确认。" end
    local reasons = quote.reasons or {}
    if #reasons == 0 then return "暂不可执行：当前家谱条件未满足。" end
    return "暂不可执行：\n· " .. table.concat(reasons, "\n· ")
end

local function actionNeedsMember(action)
    return action.inputKind == "adult" or action.inputKind == "study"
        or action.inputKind == "study_target" or action.inputKind == "work_target"
end

local function initialInput()
    return { memberId = nil, attachedInstanceIds = {} }
end

local function availableAttachments(run)
    local result = {}
    for _, instance in ipairs(run.relicInstances or {}) do
        if instance.status ~= "sold" and instance.availability ~= "sold" then
            local form = RelicState.Form(instance) or RelicDefinitions.LegacyForm(instance.definitionId)
            local familyId = form and form.familyId or instance.relicFamilyId
            if familyId == "ruler" or familyId == "plan" then
                local definition = Data.Relic(instance.definitionId)
                table.insert(result, {
                    id = instance.instanceId,
                    label = form and form.name or (definition and definition.name) or tostring(instance.definitionId),
                })
            end
        end
    end
    return result
end

local function copyInput(input)
    return State.Copy(input)
end

local function actionPreview(run, action)
    local quote = OriginSystem.Quote(run, action.id, initialInput())
    local detail = tostring(quote.description or "按当前家谱事实结算。")
    if actionNeedsMember(action) then detail = detail .. "\n选择人选后逐人核对门槛。" end
    return quoteText(quote) .. "\n" .. detail
end

local function actionCard(app, parentModal, action)
    local preview = actionPreview(app.run, action)
    return card({
        UI.Row { gap = 8, alignItems = "center", children = {
            text(action.label or action.id, { fontSize = 17, fontWeight = "bold", flex = 1, whiteSpace = "normal" }),
            text(action.inputKind == "none" and "家族" or "选人", { fontSize = 12, fontColor = C.secondary, backgroundColor = C.selected, paddingHorizontal = 7, paddingVertical = 3, borderRadius = 3 }),
        } },
        text(preview, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.35, maxLines = 4 }),
        button(actionNeedsMember(action) and "查看详情与人选" or "查看收支明细", function() View.OpenAction(app, action.id, parentModal) end, { role = "secondary", height = 44 }),
    }, { padding = 10, gap = 7, backgroundColor = C.paper })
end

local function candidateRow(member, quote, selected, onClick)
    local available = quote.allowed
    local titleColor = available and C.ink or C.disabledInk
    local summaryColor = available and C.secondary or C.danger
    return card({
        UI.Row { gap = 9, alignItems = "center", children = {
            Visual.Portrait(member, { size = 46, leader = false, selected = selected }),
            UI.Panel { flex = 1, minWidth = 0, gap = 3, children = {
                text(memberLabel(member), { fontSize = 15, fontWeight = selected and "bold" or "normal", fontColor = titleColor, whiteSpace = "normal" }),
                text(available and quoteText(quote) or reasonsText(quote), { fontSize = 12, fontColor = summaryColor, whiteSpace = "normal", lineHeight = 1.3 }),
            } },
        } },
    }, {
        padding = 8, gap = 5, backgroundColor = available and (selected and C.selected or C.paperLight) or C.disabledSurface,
        borderColor = available and (selected and C.primary or C.rule) or C.rule,
        onClick = available and onClick or nil,
    })
end

function View.Card(app)
    local record = OriginSystem.Get(app.run)
    if not record then return nil end
    local summary = OriginSystem.Summary(app.run)
    return card({
        UI.Row { gap = 8, alignItems = "center", children = {
            text(summary.title, { fontSize = 19, fontWeight = "bold", flex = 1, whiteSpace = "normal" }),
            Visual.Icon("forward", 18, "muted"),
        } },
        text(summary.originName, { fontSize = 13, fontColor = C.secondary }),
        text(summary.statusText, { fontSize = 14, fontColor = C.primary, whiteSpace = "normal" }),
        text(summary.detail, { fontSize = 14, whiteSpace = "normal", lineHeight = 1.4, maxLines = 3 }),
        text(summary.benefitsText, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.35, maxLines = 3 }),
        button("查看背景机会", function() View.Open(app) end, { role = "secondary", height = 44 }),
    }, { padding = 11, gap = 7, borderColor = C.gold, onClick = function() View.Open(app) end })
end

function View.OpenAction(app, actionId, parentModal)
    local action
    for _, candidate in ipairs(OriginSystem.Actions(app.run)) do
        if candidate.id == actionId then action = candidate; break end
    end
    if not action then app:Notify("这项背景行动当前不可用。", "warning"); return nil end
    if parentModal then parentModal:Close() end

    local input = initialInput()
    local selectedMemberId = nil
    local selectedAttachments = {}
    local candidatePanel = UI.Panel { gap = 7 }
    local attachmentPanel = UI.Panel { gap = 6 }
    local quoteLabel = text("正在核对门槛…", { fontSize = 14, whiteSpace = "normal", lineHeight = 1.45 })
    local reasonLabel = text("", { fontSize = 14, fontColor = C.danger, whiteSpace = "normal", lineHeight = 1.45 })
    ---@type Button?
    local confirmButton = nil
    local modal = ModalLayout.New("背景行动 · " .. tostring(action.label or action.id), {
        sheet = "form",
        backgroundColor = C.paperLight,
        borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary, closeOnOverlay = true,
        onClose = function(selfModal)
            if app.originActionModal == selfModal then app.originActionModal = nil end
            selfModal:Destroy()
        end,
    })
    app.originActionModal = modal

    local function currentInput()
        input.memberId = selectedMemberId
        input.attachedInstanceIds = {}
        for id, enabled in pairs(selectedAttachments) do
            if enabled then table.insert(input.attachedInstanceIds, id) end
        end
        return input
    end

    local function currentQuote()
        return OriginSystem.Quote(app.run, action.id, currentInput())
    end

    local function refreshQuote()
        local quote = currentQuote()
        quoteLabel:SetText(quoteText(quote) .. "\n\n" .. tostring(quote.description or "按当前家谱事实结算。"))
        reasonLabel:SetText(reasonsText(quote))
        return quote
    end

    local function refreshQuoteAndButton()
        local quote = refreshQuote()
        if confirmButton then confirmButton:SetDisabled(not quote.allowed) end
        return quote
    end

    local function rebuildCandidates()
        candidatePanel:ClearChildren()
        if not actionNeedsMember(action) then return end
        local candidates = livingMembers(app.run)
        local quotes = {}
        local firstAllowed
        for _, member in ipairs(candidates) do
            local candidateInput = { memberId = member.id, attachedInstanceIds = {} }
            for id, enabled in pairs(selectedAttachments) do if enabled then table.insert(candidateInput.attachedInstanceIds, id) end end
            quotes[member.id] = OriginSystem.Quote(app.run, action.id, candidateInput)
            if quotes[member.id].allowed and not firstAllowed then firstAllowed = member.id end
        end
        local selectedQuote = selectedMemberId and quotes[selectedMemberId] or nil
        if not selectedQuote or not selectedQuote.allowed then selectedMemberId = firstAllowed end
        for _, member in ipairs(candidates) do
            local candidate = member
            local quote = quotes[member.id]
            local selected = selectedMemberId == member.id
            candidatePanel:AddChild(candidateRow(candidate, quote, selected, function()
                selectedMemberId = candidate.id
                rebuildCandidates()
                refreshQuoteAndButton()
            end))
        end
        if #candidates == 0 then candidatePanel:AddChild(text("当前没有在世族人可供选择。", { fontSize = 14, fontColor = C.danger })) end
    end

    local function rebuildAttachments()
        attachmentPanel:ClearChildren()
        if not action.attachments then return end
        attachmentPanel:AddChild(text("可绑定信物 · 可多选，也可以留空", { fontSize = 14, fontWeight = "bold" }))
        local attachments = availableAttachments(app.run)
        if #attachments == 0 then
            attachmentPanel:AddChild(text("当前没有未出售的老木尺或营造图。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" }))
            return
        end
        for _, attachment in ipairs(attachments) do
            local item = attachment
            attachmentPanel:AddChild(UI.Checkbox {
                label = item.label,
                checked = selectedAttachments[item.id] == true,
                onChange = function(_, checked)
                    selectedAttachments[item.id] = checked
                    rebuildCandidates()
                    refreshQuoteAndButton()
                end,
            })
        end
    end

    confirmButton = button("确认执行", function()
        local quote = refreshQuoteAndButton()
        if not quote.allowed then return end
        local candidate = { actionId = action.id, input = copyInput(currentInput()) }
        local chosen = {}
        if candidate.input.memberId then
            table.insert(chosen, "选定族人：" .. memberLabel(State.FindMember(app.run.members, candidate.input.memberId)))
        end
        for _, id in ipairs(candidate.input.attachedInstanceIds) do
            local instance = assert(RelicState.Find(app.run, id))
            table.insert(chosen, "参与工程的信物：" .. RelicState.Form(instance).name)
        end
        table.insert(chosen, tostring(quote.description or "按当前家谱事实结算。"))
        table.insert(chosen, quoteText(quote))
        app:ConfirmRunAction(
            quote.label or action.label or action.id,
            table.concat(chosen, "\n\n"),
            function(run, profile)
                return OriginSystem.Execute(run, candidate.actionId, candidate.input)
            end,
            "确认执行", modal
        )
    end, { flex = 1 })

    local function refresh()
        rebuildAttachments()
        rebuildCandidates()
        refreshQuoteAndButton()
    end

    local body = UI.Panel { gap = 10 }
    body:AddChild(Visual.Paper({
        text(action.label or action.id, { fontSize = 22, fontWeight = "bold", whiteSpace = "normal" }),
        text("当前公库 · 银 " .. tostring(app.run.money or 0) .. " 两 · 粮 " .. tostring(app.run.grain or 0) .. " 石", { fontSize = 14, fontColor = C.primary, whiteSpace = "normal" }),
        text("选择前显示人物门槛和实际结果；确认后写入同一份家谱记录。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 }),
        actionNeedsMember(action) and text("人选", { fontSize = 16, fontWeight = "bold", marginTop = 4 }) or UI.Panel { height = 0 },
        candidatePanel,
        attachmentPanel,
        text("报价", { fontSize = 16, fontWeight = "bold", marginTop = 4 }),
        quoteLabel,
        reasonLabel,
    }, { padding = 14, gap = 9 }))
    modal:AddContent(ModalLayout.Scroll(body, { height = scrollHeight() }))
    modal:SetFooter(UI.Row { gap = 8, children = {
        button("返回", function() modal:Close() end, { flex = 1, role = "secondary" }),
        confirmButton,
    } })
    refresh()
    modal:Open()
    return modal
end

function View.Open(app)
    local record = OriginSystem.Get(app.run)
    if not record then app:Notify("旧家谱没有背景机会记录。", "warning"); return nil end
    if app.originActionModal then app.originActionModal:Close() end
    if app.originDetailModal then app.originDetailModal:Close() end
    local summary = OriginSystem.Summary(app.run)
    local modal = ModalLayout.New(summary.title, {
        sheet = "detail",
        backgroundColor = C.paperLight,
        borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary, closeOnOverlay = true,
        onClose = function(selfModal)
            if app.originDetailModal == selfModal then app.originDetailModal = nil end
            selfModal:Destroy()
        end,
    })
    app.originDetailModal = modal
    local body = UI.Panel { gap = 10 }
    body:AddChild(Visual.Paper({
        text(summary.originName, { fontSize = 14, fontColor = C.secondary }),
        text(summary.statusText, { fontSize = 20, fontWeight = "bold", whiteSpace = "normal" }),
        text("当前公库 · 银 " .. tostring(app.run.money or 0) .. " 两 · 粮 " .. tostring(app.run.grain or 0) .. " 石", { fontSize = 14, fontColor = C.primary, whiteSpace = "normal" }),
        text(summary.detail, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.45 }),
        text(summary.benefitsText, { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 }),
    }, { padding = 14, gap = 8 }))
    body:AddChild(text("可办理行动", { fontSize = 20, fontWeight = "bold", marginTop = 4 }))
    local actions = OriginSystem.Actions(app.run)
    if #actions == 0 then
        body:AddChild(card({ text("当前没有可办理行动。", { fontSize = 15, fontColor = C.secondary }) }))
    else
        for _, action in ipairs(actions) do body:AddChild(actionCard(app, modal, action)) end
    end
    modal:AddContent(ModalLayout.Scroll(body, { height = scrollHeight() }))
    modal:SetFooter(button("关闭", function() modal:Close() end, { width = "100%", role = "secondary" }))
    modal:Open()
    return modal
end

return View
