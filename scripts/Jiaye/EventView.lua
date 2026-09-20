local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Visual = require "Jiaye.Visual"
local V7 = require "Jiaye.V7"

local EventView = {}
local C = V7.Colors

local function findMember(run, memberId)
    return memberId and State.FindMember(run.members, memberId) or nil
end

local function findRelic(run, instanceId)
    for _, instance in ipairs(run.relicInstances or {}) do
        if instance.instanceId == instanceId then return instance end
    end
    return nil
end

local function relicIdFor(run, event)
    local instance = event.relicInstanceId and findRelic(run, event.relicInstanceId)
    return instance and instance.definitionId or nil
end

local function memberName(member)
    return member and (member.name .. " · " .. tostring(member.age) .. "岁") or "待指定"
end

local function livingAdults(run)
    local result = {}
    for _, member in ipairs(run.members or {}) do
        if member.alive and State.IsAdult(member) then table.insert(result, member) end
    end
    return result
end

local function choiceList(run, event)
    if event.type == "leader" then
        local choices = {}
        for _, member in ipairs(livingAdults(run)) do
            table.insert(choices, { id = tostring(member.id), memberId = member.id, label = "任命 " .. member.name, cost = 0, years = 0, result = { status = "new_term" } })
        end
        return choices
    end
    if event.type == "relic_resolution" then
        local relic = assert(Data.Relic(relicIdFor(run, event)), "信物结果缺少有效物件。")
        local source = Data.EventChoices.relic_resolution
        if type(event.choiceSchema) == "table" and #event.choiceSchema > 0 then source = event.choiceSchema
        elseif type(event.choices) == "table" and #event.choices > 0 then source = event.choices end
        local choices = State.Copy(source)
        for _, choice in ipairs(choices) do
            if choice.id == "restore" then
                choice.label = relic.story.restore
                choice.result.relicId = relic.unlock
                choice.result.unlock = relic.unlock
            else
                choice.label = relic.story.defer
            end
        end
        return choices
    end
    if type(event.choiceSchema) == "table" and #event.choiceSchema > 0 then return event.choiceSchema end
    if type(event.choices) == "table" and #event.choices > 0 then return event.choices end
    if event.type == "legacy_pending" then return { { id = "acknowledge", label = "确认并写入家史", cost = 0, years = 0, result = { status = "recorded" } } } end
    return Data.EventChoices[event.type] or {}
end

local function requiredFunds(choice)
    return math.max(tonumber(choice.cost) or 0, tonumber(choice.requiredMoney) or 0)
end

local function choiceQuote(choice)
    local cost = tonumber(choice.cost) or 0
    local requiredMoney = tonumber(choice.requiredMoney) or 0
    local years = tonumber(choice.years) or 0
    local costText
    if requiredMoney > cost then
        costText = "需" .. tostring(requiredMoney) .. "两工料周转"
    else
        costText = cost > 0 and ("成本 " .. tostring(cost) .. " 两") or "不花钱"
    end
    local waitText = years > 0 and ("等待约 " .. tostring(years) .. " 年") or "当年见结果"
    if choice.id == "pause" or (type(choice.result) == "table" and choice.result.reward == "deferred") then waitText = "日后仍可继续" end
    local parts = { costText }
    if type(choice.result) == "table" and tonumber(choice.result.money) and tonumber(choice.result.money) > 0 and requiredMoney > 0 then
        table.insert(parts, "结算净增" .. tostring(choice.result.money))
    end
    table.insert(parts, waitText)
    return table.concat(parts, " · ")
end

local function resultText(choice)
    local result = choice.result
    if type(result) == "string" then return result end
    if type(result) ~= "table" then return "处理结果会写入本局家史。" end
    local lines = {}
    if result.money then table.insert(lines, (result.money > 0 and "公库 +" or "公库 ") .. tostring(result.money) .. " 两") end
    if result.reputation then table.insert(lines, "声望 " .. (result.reputation > 0 and "+" or "") .. tostring(result.reputation)) end
    if result.learn then table.insert(lines, "在读族人学识 +" .. tostring(result.learn)) end
    if result.relicId then
        local relic = Data.Relic(result.relicId)
        table.insert(lines, "信物“" .. tostring(relic and relic.name or "新信物") .. "”进入本局藏阁")
    end
    if result.unlock then table.insert(lines, "解锁收藏资格") end
    if result.homeState then
        local homeStates = { normal = "整修妥当", damaged = "待修补", upgraded = "已修整", relocated = "迁居后" }
        table.insert(lines, "家宅状态：" .. tostring(homeStates[result.homeState] or "状态待定"))
    end
    if result.stage then
        local stages = {
            investigating = "调查中", fast = "快查中", slow = "慢查中", resumed = "调查已恢复",
            paused = "调查暂缓", awaiting_executor = "等待执行人", awaiting_resolution = "线索已到",
            awaiting_choice = "等待决定", completed = "已完成", clue_saved = "线索暂存",
            work_offered = "已有修缮活", work_completed = "修缮已完成", work_deferred = "修缮暂缓",
            reunited = "故人已重逢", printed = "已刊印", passed = "已传承",
        }
        table.insert(lines, "后续阶段：" .. tostring(stages[result.stage] or "后续进行中"))
    end
    if result.reunited then table.insert(lines, "寻回故人后辈，玉佩完成重逢") end
    if result.aid then table.insert(lines, "乡里接济次数 +" .. tostring(result.aid)) end
    if result.status == "deferred" then table.insert(lines, "线索暂存，之后仍可继续") end
    if result.status == "recorded" then table.insert(lines, "这次机会记入家史") end
    if result.status == "new_term" then table.insert(lines, "开始新的族长任期") end
    if result.reward == "grant" and not result.relicId then table.insert(lines, "登记一次后续奖励") end
    if result.reward == "deferred" then table.insert(lines, "奖励暂缓，线索留存") end
    if #lines == 0 then return "处理结果会写入本局家史。" end
    return table.concat(lines, " · ")
end

local function sourceText(event)
    local source = {
        relic_resolution = "信物调查",
        medical_find = "医馆托付",
        plan_work = "营造图线索",
        jade_search = "玉佩查访",
        school = "族中孩子",
        community_request = "乡里来信",
        roof = "家宅日常",
        notes_choice = "批注医案",
        growth = "人生节点",
        leader = "族长任期",
        legacy_pending = "迁入家史",
    }
    return event.source or source[event.type] or "家中事务"
end

local function eventBody(run, event)
    if event.body then return event.body end
    if event.desc then return event.desc end
    local relic = event.relicInstanceId and findRelic(run, event.relicInstanceId)
    local relicDefinition = relic and Data.Relic(relic.definitionId)
    local member = findMember(run, event.executorId or event.memberId)
    if event.type == "legacy_pending" then
        local detail = event.legacyDetail
        if type(detail) == "table" then
            return detail.body or detail.desc or detail.description or detail.detail
                or "这件迁入家谱的旧版家事保留了原始记录，确认后只追加迁移事实。"
        end
        return "这件迁入家谱的旧版家事保留了原始记录，确认后只追加迁移事实。"
    end
    if event.type == "leader" then return "家中暂时没有族长。需要从在世成年族人中选出一人，接过任期与照料全家的责任。" end
    if event.type == "growth" and member then
        if event.growthId == "promotion" then
            local job = event.jobId and Data.Jobs[event.jobId]
            return member.name .. "已经把“" .. tostring(job and job.name or "下一步安排") .. "所需的本领练成了。确认后只记录这项资格，岗位仍由你另行安排。"
        end
        return member.name .. "已经成年，接下来要由家中决定他如何谋生、求学或照料家业。"
    end
    if event.type == "medical_find" then return "行医多年后，医馆愿把一册带有批注的医案交给" .. (member and member.name or "家中") .. "。收下会把这段医术和后续选择带回家中。" end
    if event.type == "school" then return "孩子还在长大，先生提醒家中添置一批书本。花费会落在本年家用上，收获会留在每个仍在读书的孩子身上。" end
    if event.type == "community_request" then return "邻里来借一笔周转钱，眼下确实有急用。家中可以伸手相助，也可以把银钱留给自己的日常开销。" end
    if event.type == "roof" then return "雨季将近，屋顶的破损已经到了需要处理的程度。现在修补会花费公库，暂缓则把这处隐患留到以后。" end
    if event.type == "plan_work" and relicDefinition then return "" .. relicDefinition.desc .. "眼下有一桩修缮活找上门，接下它要先备好工料，做成后会留下收入、声望与一段信物后续。" end
    if event.type == "jade_search" and relicDefinition then return relicDefinition.desc .. "这次查访已经找到新的去向，是否现在花路费追下去，由家中决定。" end
    if event.type == "notes_choice" and relicDefinition then return relicDefinition.desc .. "医馆把去向交给家中：刊印会让医术留下更广的记录，传给后人则让它继续在家中流传。" end
    if event.type == "relic_resolution" and relicDefinition then
        local executor = findMember(run, event.executorId or (relic and relic.executorId))
        return "“" .. relicDefinition.name .. "”的调查已经有了结果。" .. (executor and executor.name or "执行人") .. "带回这段线索：" .. relicDefinition.desc .. "可以“" .. tostring(relicDefinition.story.restore or "完成后续") .. "”，也可以“" .. tostring(relicDefinition.story.defer or "暂存线索") .. "”。"
    end
    local bodies = {
        plan_work = "旧物留下的线索终于牵出一桩眼前的家事，接下它会消耗工料并留下后续记录。",
        jade_search = "半枚玉佩的新线索指向一位故人的后辈，查访与暂存都会成为家史的一部分。",
        notes_choice = "这册医案已经交到家中，下一步决定它会以公开记录还是家传手稿留下。",
    }
    return bodies[event.type] or "这件家事已经进入本年的家谱记录，需要你决定它如何继续。"
end

local function fixedParticipant(run, event)
    return findMember(run, event.executorId or event.memberId)
end

local function participantCandidates(run, event)
    local ids = event.participantIds or event.candidateMemberIds or event.memberIds
    local candidates = {}
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            local member = findMember(run, id)
            if member and member.alive then table.insert(candidates, member) end
        end
    elseif event.participantMode == "optional" then
        candidates = livingAdults(run)
    end
    return candidates
end

local function participantBlock(run, event, onChange)
    local fixed = fixedParticipant(run, event)
    local candidates = participantCandidates(run, event)
    if fixed and #candidates == 0 then
        return UI.Row { gap = 9, alignItems = "center", children = {
            Visual.Portrait(fixed, { size = 44, leader = fixed.id == run.leaderId }),
            Visual.Text("参与人 · " .. memberName(fixed), { fontSize = 15, fontWeight = "bold" }),
        } }, fixed.id
    end
    if #candidates == 0 then
        return Visual.Text("参与人 · 全家共同承担", { fontSize = 15, fontWeight = "bold" }), nil
    end
    local options = {}
    for _, member in ipairs(candidates) do table.insert(options, { value = member.id, label = memberName(member) }) end
    local initial = fixed and fixed.id or candidates[1].id
    local participantLabel = Visual.Text("参与人 · " .. memberName(findMember(run, initial)), { fontSize = 14, fontColor = C.secondary })
    local dropdown = UI.Dropdown {
        options = options, value = initial, height = 44, fontSize = V7.Font(15),
        triggerBgColor = C.paperLight, borderColor = C.rule, openBorderColor = C.gold,
        onChange = function(_, value)
            local member = findMember(run, value)
            participantLabel:SetText("参与人 · " .. memberName(member))
            onChange(value)
        end,
    }
    return UI.Panel { gap = 6, children = { participantLabel, dropdown } }, initial
end

local function choiceRow(choice, selected, disabled, onClick)
    local radio = UI.Panel {
        width = 18, height = 18, flexShrink = 0, borderWidth = 1, borderRadius = 9,
        borderColor = disabled and C.rule or (selected and C.primary or C.gold),
        backgroundColor = disabled and C.disabledSurface or (selected and C.primary or C.paperLight),
    }
    local title = Visual.Text(choice.label, { fontSize = 15, fontWeight = selected and "bold" or "normal", whiteSpace = "normal", lineHeight = 1.1, fontColor = disabled and C.disabledInk or C.ink })
    local summary = Visual.Text(choiceQuote(choice), { fontSize = 12, lineHeight = 1.1, fontColor = disabled and C.disabledInk or C.secondary, whiteSpace = "normal" })
    local row = UI.Panel {
        width = "100%", minHeight = 60, flexDirection = "row", alignItems = "center", gap = 10,
        padding = 8, borderWidth = 1, borderRadius = 2, flexShrink = 0,
        borderColor = disabled and C.rule or (selected and C.primary or C.rule),
        backgroundColor = disabled and C.disabledSurface or (selected and C.selected or C.paperLight),
        hoverBackgroundColor = disabled and C.disabledSurface or C.selected,
        pressedBackgroundColor = disabled and C.disabledSurface or C.rule,
        onClick = not disabled and function() onClick() end or nil,
        children = { radio, UI.Panel { flex = 1, minWidth = 0, gap = 3, children = { title, summary } } },
    }
    return { choice = choice, row = row, radio = radio, title = title, summary = summary, disabled = disabled }
end

local function openModal(app, title, content, footer)
    local modal = UI.Modal {
        title = title, size = "fullscreen", backgroundColor = C.paperLight,
        borderColor = C.gold, titleTextColor = C.gold, closeIconColor = C.secondary,
        headerHeight = 44, titleFontSize = V7.Font(13), contentPadding = 0, borderRadius = 2,
        closeOnOverlay = true,
        onClose = function(selfModal) selfModal:Destroy() end,
    }
    local contentHeight = math.max(200, (UI.GetHeight() or 600) * 0.9 - 120)
    modal:AddContent(UI.Panel {
        height = contentHeight, minHeight = contentHeight, maxHeight = contentHeight,
        flexGrow = 0, flexShrink = 0, flexDirection = "column", padding = 0,
        children = { UI.ScrollView {
            height = contentHeight, minHeight = contentHeight, maxHeight = contentHeight,
            flexGrow = 0, flexShrink = 0, padding = 0, children = { content },
        } },
    })
    modal:SetFooter(footer)
    modal:Open()
    return modal
end

local function resolveLeader(app, event, memberId)
    return Simulation.ResolveLeaderEvent(app.run, event.instanceId, memberId)
end

function EventView.Card(app, event)
    local run = app.run
    local image = Visual.EventImage(event, { height = 88, relicId = relicIdFor(run, event) })
    local participant = fixedParticipant(run, event)
    local children = {
        image,
        UI.Row { justifyContent = "space-between", alignItems = "center", children = {
            Visual.Text(event.title or "家中事务", { fontSize = 18, fontWeight = "bold", flex = 1 }),
            Visual.Icon("forward", 20, "muted"),
        } },
        Visual.Text("来源 · " .. sourceText(event) .. (participant and (" · " .. participant.name) or ""), { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" }),
        Visual.Text(event.desc or "这件家事等待你的决定。", { fontSize = 15, whiteSpace = "normal", lineHeight = 1.45, maxLines = 3 }),
    }
    return Visual.Card(children, {
        onClick = function() EventView.Open(app, event) end,
        borderColor = C.gold, padding = 10, gap = 7,
    })
end

function EventView.Open(app, event)
    local run = app.run
    local choices = choiceList(run, event)
    if #choices == 0 then
        if app.Notify then app:Notify("这件家事没有可用的决定。", "warning") end
        return nil
    end

    local selectedChoice = choices[1]
    for _, choice in ipairs(choices) do
        if requiredFunds(choice) <= (tonumber(run.money) or 0) then
            selectedChoice = choice
            break
        end
    end
    local selectedParticipantId = nil
    local resultSummary = Visual.Text(resultText(selectedChoice), { fontSize = 14, whiteSpace = "normal", lineHeight = 1.4 })
    local choiceButtons = {}
    local modal

    local function selectChoice(choice)
        selectedChoice = choice
        resultSummary:SetText(resultText(choice))
        for _, item in ipairs(choiceButtons) do
            local active = item.choice.id == choice.id
            item.row:SetStyle({
                backgroundColor = item.disabled and C.disabledSurface or (active and C.selected or C.paperLight),
                borderColor = item.disabled and C.rule or (active and C.primary or C.rule),
                hoverBackgroundColor = item.disabled and C.disabledSurface or C.selected,
                pressedBackgroundColor = item.disabled and C.disabledSurface or C.rule,
            })
            item.radio:SetStyle({
                backgroundColor = item.disabled and C.disabledSurface or (active and C.primary or C.paperLight),
                borderColor = item.disabled and C.rule or (active and C.primary or C.gold),
            })
            item.title:SetStyle({ fontColor = item.disabled and C.disabledInk or C.ink, fontWeight = active and "bold" or "normal" })
            item.summary:SetStyle({ fontColor = item.disabled and C.disabledInk or C.secondary })
        end
    end

    local choiceChildren = {}
    for _, choice in ipairs(choices) do
        local disabled = requiredFunds(choice) > (tonumber(run.money) or 0)
        local row = choiceRow(choice, choice.id == selectedChoice.id, disabled, function() selectChoice(choice) end)
        table.insert(choiceButtons, row)
        table.insert(choiceChildren, row.row)
    end

    local participant, initialParticipant = participantBlock(run, event, function(value) selectedParticipantId = value end)
    selectedParticipantId = initialParticipant
    local contentChildren = {
        Visual.Text(event.title or "家族事件", { fontSize = 22, textAlign = "center", whiteSpace = "normal", lineHeight = 1.1 }),
        Visual.EventImage(event, { height = 120, relicId = relicIdFor(run, event), borderRadius = 0 }),
        Visual.Text("来源 · " .. sourceText(event), { fontSize = 12, fontColor = C.secondary }),
        Visual.Text(eventBody(run, event), { fontSize = 15, whiteSpace = "normal", lineHeight = 1.4 }),
        participant,
        UI.Panel { gap = 8, children = choiceChildren },
        resultSummary,
    }

    local submitted = false
    local confirm = Visual.Button("确认这个决定", function()
        if submitted then return end
        submitted = true
        local ok = app:RunAction(function()
            local currentEvent
            for _, item in ipairs(app.run.events or {}) do
                if item.instanceId == event.instanceId then currentEvent = item; break end
            end
            if not currentEvent then return false, "这件家事已经处理或不存在。" end
            if selectedParticipantId then
                if currentEvent.executorId then currentEvent.executorId = selectedParticipantId else currentEvent.memberId = selectedParticipantId end
            end
            if event.type == "leader" then return resolveLeader(app, currentEvent, selectedChoice.memberId) end
            return Simulation.ResolveEvent(app.run, currentEvent.instanceId, selectedChoice.id, app.profile)
        end)
        if ok then modal:Close() else submitted = false end
    end, { flex = 1, height = 48, confirm = true })

    local footer = UI.Row { children = { confirm } }
    modal = openModal(app, "家族事件", Visual.Paper(contentChildren, { gap = 10, padding = 14, borderRadius = 0 }), footer)
    return modal
end

function EventView.OpenRelic(app, instance)
    local run = app.run
    local relic = Data.Relic(instance.definitionId)
    if not relic then
        if app.Notify then app:Notify("信物定义不存在。", "warning") end
        return nil
    end
    if instance.rewardState == "granted" or instance.stage == "completed" then
        if app.Notify then app:Notify("这件信物的后续已经完成。", "warning") end
        return nil
    end
    local adults = livingAdults(run)
    local function adultById(memberId)
        for _, member in ipairs(adults) do
            if member.id == memberId then return member end
        end
        return nil
    end
    local initialExecutor = adultById(instance.executorId) or adultById(instance.custodianId) or adults[1]
    local selectedExecutorId = initialExecutor and initialExecutor.id or nil
    local executorOptions = {}
    for _, member in ipairs(adults) do table.insert(executorOptions, { value = member.id, label = memberName(member) }) end
    local executorDropdown = UI.Dropdown {
        options = executorOptions, value = selectedExecutorId, height = 44, fontSize = V7.Font(15), flex = 1, minWidth = 0,
        triggerBgColor = C.paperLight, borderColor = C.rule, openBorderColor = C.gold,
        onChange = function(_, value)
            selectedExecutorId = value
        end,
    }
    local fast = Data.EventChoice("relic_investigation", "fast")
    local slow = Data.EventChoice("relic_investigation", "slow")
    local fastStory = relic.story.fast
    local slowStory = relic.story.slow
    local options
    if instance.status == "awaiting_resolution" or instance.pendingEventId then
        if app.Notify then app:Notify("这件信物已有待决结果，请先处理家事卡。", "warning") end
        return nil
    elseif instance.status == "held" and instance.stage == "clue_saved" then
        options = { { id = "continue", label = "继续处理已找到的线索", cost = 0, years = 0, result = { stage = "awaiting_resolution" } } }
    elseif instance.status == "held" and (instance.stage == "paused" or instance.stage == "awaiting_executor") then
        options = { { id = "resume", label = "恢复调查", cost = 0, years = instance.remainingYears or 1, result = { stage = "investigating" } } }
    elseif instance.status == "investigating" then
        options = { { id = "pause", label = "暂缓，保留线索", cost = 0, years = 0, result = { status = "deferred" } } }
    else
        options = {
            { id = "fast", label = fastStory and fastStory.label or fast.label, cost = fast.cost, years = fast.years, result = fast.result },
            { id = "slow", label = slowStory and slowStory.label or slow.label, cost = slow.cost, years = slow.years, result = slow.result },
            { id = "pause", label = "暂缓，保留线索", cost = 0, years = 0, result = { status = "deferred" } },
        }
    end
    local selected = options[1]
    for _, option in ipairs(options) do
        if requiredFunds(option) <= (tonumber(run.money) or 0) then
            selected = option
            break
        end
    end
    local outcome = Visual.Text(selected.id == "pause" and "线索保留，之后可以继续。" or "主业保持原安排，调查与后续写入家史。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.2 })
    local buttons = {}
    local function select(option)
        selected = option
        outcome:SetText(option.id == "pause" and "线索保留，之后可以继续。" or "主业保持原安排，调查与后续写入家史。")
        for _, item in ipairs(buttons) do
            local active = item.option.id == option.id
            item.row:SetStyle({
                backgroundColor = item.disabled and C.disabledSurface or (active and C.selected or C.paperLight),
                borderColor = item.disabled and C.rule or (active and C.primary or C.rule),
                hoverBackgroundColor = item.disabled and C.disabledSurface or C.selected,
                pressedBackgroundColor = item.disabled and C.disabledSurface or C.rule,
            })
            item.radio:SetStyle({
                backgroundColor = item.disabled and C.disabledSurface or (active and C.primary or C.paperLight),
                borderColor = item.disabled and C.rule or (active and C.primary or C.gold),
            })
            item.title:SetStyle({ fontWeight = active and "bold" or "normal", fontColor = item.disabled and C.disabledInk or C.ink })
            item.summary:SetStyle({ fontColor = item.disabled and C.disabledInk or C.secondary })
        end
    end
    local choiceChildren = {}
    for _, option in ipairs(options) do
        local disabled = option.id ~= "pause" and option.id ~= "resume" and requiredFunds(option) > (tonumber(run.money) or 0)
        local row = choiceRow(option, option == selected, disabled, function() select(option) end)
        table.insert(buttons, { option = option, row = row.row, radio = row.radio, title = row.title, summary = row.summary, disabled = disabled })
        table.insert(choiceChildren, row.row)
    end
    local submitted = false
    local modal
    local confirm = Visual.Button("确认这个决定", function()
        if submitted then return end
        submitted = true
        local ok = app:RunAction(function()
            if not selectedExecutorId then return false, "需要指定一位在世成年人。" end
            local current
            for _, item in ipairs(app.run.relicInstances or {}) do if item.instanceId == instance.instanceId then current = item; break end end
            if not current then return false, "此物件已不在家中。" end
            if selected.id == "pause" then
                if current.status == "investigating" then return Simulation.PauseRelicInvestigation(app.run, instance.instanceId) end
                return true, "调查暂不开始，信物仍保留在当前阶段。"
            end
            if selected.id == "resume" then
                if selectedExecutorId ~= current.executorId then
                    local assigned, assignMessage = Simulation.AssignRelicExecutor(app.run, instance.instanceId, selectedExecutorId)
                    if not assigned then return false, assignMessage end
                end
                return Simulation.ResumeRelicInvestigation(app.run, instance.instanceId)
            end
            if selected.id == "continue" then
                if selectedExecutorId ~= current.executorId then
                    local assigned, assignMessage = Simulation.AssignRelicExecutor(app.run, instance.instanceId, selectedExecutorId)
                    if not assigned then return false, assignMessage end
                end
                return Simulation.ResumeRelicStory(app.run, instance.instanceId)
            end
            return Simulation.StartRelicInvestigation(app.run, instance.instanceId, selected.id, selectedExecutorId)
        end)
        if ok then modal:Close() else submitted = false end
    end, { flex = 1, height = 48, confirm = true })
    local relicEvent = { type = "relic_resolution" }
    local content = Visual.Paper({
        Visual.Text(relic.story.title or relic.name, { fontSize = 22, textAlign = "center", whiteSpace = "normal", lineHeight = 1.1 }),
        Visual.EventImage(relicEvent, { height = 120, relicId = instance.definitionId, borderRadius = 0 }),
        Visual.Text("来自 " .. relic.name .. " · " .. tostring(instance.source or relic.story.source), { fontSize = 12, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.1 }),
        Visual.Text(relic.story.body or relic.desc, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.4 }),
        UI.Row { gap = 8, alignItems = "center", children = {
            Visual.Text("交给谁办理", { fontSize = 14 }), executorDropdown,
        } },
        UI.Panel { gap = 8, children = choiceChildren },
        outcome,
    }, { gap = 10, padding = 14, borderRadius = 0 })
    modal = openModal(app, "家族事件", content, UI.Row { children = { confirm } })
    return modal
end

return EventView
