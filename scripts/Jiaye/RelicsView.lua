local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Visual = require "Jiaye.Visual"
local V7 = require "Jiaye.V7"
local EventView = require "Jiaye.EventView"
local RelicState = require "Jiaye.RelicState"
local RelicV12View = require "Jiaye.RelicV12View"
local ModalLayout = require "Jiaye.ModalLayout"

local RelicsView = {}
local C = V7.Colors

local function findMember(run, memberId)
    return memberId and State.FindMember(run.members, memberId) or nil
end

local function findInstance(run, definitionId)
    for _, instance in ipairs(run.relicInstances or {}) do
        if instance.definitionId == definitionId then return instance end
    end
    return nil
end

local function findInstanceById(run, instanceId)
    for _, instance in ipairs(run.relicInstances or {}) do
        if instance.instanceId == instanceId then return instance end
    end
    return nil
end

local function adults(run)
    local result = {}
    for _, member in ipairs(run.members or {}) do
        if member.alive and State.IsAdult(member) then table.insert(result, member) end
    end
    return result
end

local function adultById(candidates, memberId)
    for _, member in ipairs(candidates) do
        if member.id == memberId then return member end
    end
    return nil
end

local function stageText(instance)
    if instance.status == "sold" or instance.stage == "closed" then return "已出售" end
    if instance.status == "awaiting_resolution" then return "线索已到" end
    if instance.status == "investigating" then
        local names = { fast = "快查中", slow = "慢查中", resumed = "调查已恢复" }
        return names[instance.stage] or "调查中"
    end
    local names = {
        idle = "尚未开始", paused = "调查暂缓", awaiting_executor = "等待执行人", awaiting_choice = "等待决定",
        completed = "已完成", clue_saved = "线索暂存", work_offered = "已有修缮活", work_completed = "修缮已完成",
        work_deferred = "修缮暂缓", reunited = "故人已重逢", printed = "已刊印", passed = "已传承",
    }
    return names[instance.stage] or instance.stage or "尚未开始"
end

local function memberText(member)
    return member and (member.name .. " · " .. tostring(member.age) .. "岁") or "待指定"
end

local function pendingEvent(run, instance)
    local eventId = instance.pendingEventId
    for _, event in ipairs(run.events or {}) do
        if event.instanceId == eventId and event.status == "pending" then return event end
    end
    for _, event in ipairs(run.events or {}) do
        if event.status == "pending" and event.relicInstanceId == instance.instanceId then return event end
    end
    return nil
end

local function actionModal(app, title, detail, action, confirmText, extra)
    local modal = ModalLayout.New(title, {
        backgroundColor = C.paperLight,
        borderColor = C.rule, titleTextColor = C.ink, closeIconColor = C.secondary,
        closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end,
    })
    local bodyChildren = { Visual.Text(detail, { fontSize = 16, whiteSpace = "normal", lineHeight = 1.6 }) }
    if extra then table.insert(bodyChildren, extra) end
    local body = Visual.Paper(bodyChildren, { gap = 12, padding = 14 })
    if ModalLayout.NeedsScroll(detail) then
        modal:AddContent(ModalLayout.Scroll(body))
    else
        modal:AddContent(body)
    end
    local submitted = false
    modal:SetFooter(UI.Row { gap = 8, children = {
        Visual.Button("返回", function() modal:Close() end, { role = "secondary", flex = 1, height = 48 }),
        Visual.Button(confirmText or "确认执行", function()
            if submitted then return end
            submitted = true
            local ok = app:RunAction(action)
            if ok then modal:Close() else submitted = false end
        end, { flex = 1, height = 48, confirm = true }),
    } })
    modal:Open()
    return modal
end

local function personActionModal(app, instance, kind)
    local run = app.run
    local candidates = adults(run)
    local currentId = kind == "custodian" and instance.custodianId or instance.executorId
    local selected = adultById(candidates, currentId) or candidates[1]
    local selectedId = selected and selected.id or nil
    local label = kind == "custodian" and "保管人" or "执行人"
    local labelWidget = Visual.Text(label .. " · " .. memberText(findMember(run, selectedId)), { fontSize = 14, fontColor = C.secondary })
    local options = {}
    for _, member in ipairs(candidates) do table.insert(options, { value = member.id, label = memberText(member) }) end
    local dropdown = UI.Dropdown {
        options = options, value = selectedId, height = 44, fontSize = V7.Font(15),
        triggerBgColor = C.paperLight, borderColor = C.rule, openBorderColor = C.gold,
        onChange = function(_, value)
            selectedId = value
            labelWidget:SetText(label .. " · " .. memberText(findMember(run, value)))
        end,
    }
    local title = kind == "custodian" and "确认更换保管人" or "确认指定执行人"
    local detail = kind == "custodian" and "物件仍留在本局，调查阶段、故事进度与已写入家史都会保留。" or "执行人只影响后续办理人，不会替换当前主业；离世后仍可重新托付。"
    local function action()
        if not selectedId then return false, "需要选择一位在世成年人。" end
        if kind == "custodian" then return Simulation.TransferRelic(app.run, instance.instanceId, selectedId) end
        return Simulation.AssignRelicExecutor(app.run, instance.instanceId, selectedId)
    end
    return actionModal(app, title, detail, action, kind == "custodian" and "确认托付" or "确认安排", UI.Panel { gap = 6, children = { labelWidget, dropdown } })
end

local function executorActionModal(app, instance, title, detail, command, confirmText)
    local run = app.run
    local candidates = adults(run)
    local selected = adultById(candidates, instance.executorId) or adultById(candidates, instance.custodianId) or candidates[1]
    local selectedId = selected and selected.id or nil
    local label = Visual.Text("执行人 · " .. memberText(findMember(run, selectedId)), { fontSize = 14, fontColor = C.secondary })
    local options = {}
    for _, member in ipairs(candidates) do table.insert(options, { value = member.id, label = memberText(member) }) end
    local dropdown = UI.Dropdown {
        options = options, value = selectedId, height = 44, fontSize = V7.Font(15),
        triggerBgColor = C.paperLight, borderColor = C.rule, openBorderColor = C.gold,
        onChange = function(_, value)
            selectedId = value
            label:SetText("执行人 · " .. memberText(findMember(run, value)))
        end,
    }
    local function action()
        if not selectedId then return false, "需要选择一位在世成年人。" end
        return command(app.run, instance.instanceId, selectedId)
    end
    return actionModal(app, title, detail, action, confirmText, UI.Panel { gap = 6, children = { label, dropdown } })
end

local function sellModal(app, instance, relic)
    local value = relic.saleValue or relic.cost * 2
    return actionModal(app, "确认出售 · " .. relic.name, "出售后本局物件和未完成后续会停止；已经写入家史的事实与下一局解锁资格仍然保留。收入：" .. tostring(value) .. " 两。", function()
        return Simulation.SellRelic(app.run, instance.instanceId)
    end, "确认出售")
end

local function followUp(app, instance, relic)
    local actions = {}
    local flags = app.run.flags or {}
    if relic.id == "newbook" and not flags.branchInvited and instance.status ~= "sold" then
        table.insert(actions, Visual.Button("邀请成年旁支归家 · 12 两", function()
            executorActionModal(app, instance, "确认寻回成年旁支", "补完的族谱会把一位成年旁支写回家谱，安置费用在确认后扣除。", function(run, instanceId)
                local ok, message = Simulation.InviteBranch(run, instanceId)
                return ok, message
            end, "确认寻亲")
        end, { role = "secondary", height = 44 }))
    elseif relic.id == "jade" and not flags.jadeReunited and instance.status ~= "sold" then
        table.insert(actions, Visual.Button("发起查访 · 结果时花 8 两", function()
            executorActionModal(app, instance, "确认发起玉佩查访", "先记录查访人和线索，真正的路费在选择查访结果时结算。", function(run, instanceId, memberId)
                return Simulation.StartJadeSearch(run, instanceId, memberId)
            end, "确认查访")
        end, { role = "secondary", height = 44 }))
    elseif (relic.id == "plan" or relic.id == "notes") and instance.status == "held" and instance.stage == "awaiting_executor" and not instance.pendingEventId then
        table.insert(actions, Visual.Button("重新安排后续", function()
            executorActionModal(app, instance, "确认重新安排后续", "重新指定在世执行人后，信物故事会回到可处理状态。", function(run, instanceId, memberId)
                local current = findInstanceById(run, instanceId)
                if not current then return false, "此物件已不在家中。" end
                local ok, message = Simulation.AssignRelicExecutor(run, instanceId, memberId)
                if not ok then return false, message end
                return Simulation.ResumeRelicStory(run, instanceId)
            end, "确认恢复")
        end, { role = "secondary", height = 44 }))
    end
    return actions
end

local function instanceCard(app, instance, relic)
    local run = app.run
    local custodian = findMember(run, instance.custodianId)
    local executor = findMember(run, instance.executorId)
    local detail = "来源 · " .. tostring(instance.source or relic.story.source or "家中旧事") .. "\n状态 · " .. stageText(instance)
    if custodian then detail = detail .. "\n保管人 · " .. custodian.name end
    if executor then detail = detail .. " · 执行人 · " .. executor.name end
    if instance.dueYear and instance.status == "investigating" then
        local remaining = math.max(0, instance.dueYear - run.yearIndex)
        detail = detail .. "\n预计约 " .. tostring(remaining) .. " 年后有消息"
    end
    if instance.remainingYears and instance.stage == "paused" then detail = detail .. "\n暂存约 " .. tostring(instance.remainingYears) .. " 年" end
    local actions = {}
    if instance.status ~= "sold" and not run.ending then
        local pending = pendingEvent(run, instance)
        local investigating = instance.status == "investigating"
        local awaitingResolution = instance.status == "awaiting_resolution" or (pending and pending.type == "relic_resolution")
        local hasReward = instance.rewardState == "granted" or instance.stage == "completed"
        if relic.basic and not hasReward and not awaitingResolution then
            local actionText = investigating and "调整调查" or (instance.stage == "clue_saved" and "继续线索" or "开始调查")
            table.insert(actions, Visual.Button(actionText, function() EventView.OpenRelic(app, instance) end, { height = 44 }))
        end
        if pending then
            table.insert(actions, Visual.Button("处理这件家事", function() EventView.Open(app, pending) end, { role = "secondary", height = 44 }))
        end
        for _, button in ipairs(followUp(app, instance, relic)) do table.insert(actions, button) end
        if instance.status == "held" then
            table.insert(actions, Visual.Button("更换保管人", function() personActionModal(app, instance, "custodian") end, { role = "secondary", height = 44 }))
        else
            table.insert(actions, Visual.Text("当前办理进行中，保管人保持不变。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" }))
        end
        table.insert(actions, Visual.Button("指定执行人", function() personActionModal(app, instance, "executor") end, { role = "secondary", height = 44 }))
        if instance.status == "investigating" then
            table.insert(actions, Visual.Button("暂缓调查", function() EventView.OpenRelic(app, instance) end, { role = "secondary", height = 44 }))
        elseif instance.status == "held" and (instance.stage == "paused" or instance.stage == "awaiting_executor") then
            table.insert(actions, Visual.Button("恢复调查", function() EventView.OpenRelic(app, instance) end, { height = 44 }))
        end
        table.insert(actions, Visual.Button("出售 · " .. tostring(relic.saleValue or relic.cost * 2) .. " 两", function() sellModal(app, instance, relic) end, { role = "danger", height = 44 }))
    elseif instance.status == "sold" then
        table.insert(actions, Visual.Text("已出售 · 本局效果停止，历史与收藏资格保留。", { fontSize = 13, fontColor = C.danger, whiteSpace = "normal" }))
    end
    if run.ending then table.insert(actions, Visual.Text("本局已落笔，物件状态、保管人与调查记录均已封存。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" })) end
    return Visual.Card({
        UI.Row { gap = 10, alignItems = "center", children = {
            Visual.Relic(relic.id, 72),
            UI.Panel { flex = 1, minWidth = 0, gap = 3, children = {
                Visual.Text(relic.name, { fontSize = 18, fontWeight = "bold" }),
                Visual.Text(detail, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 }),
            } },
        } },
        Visual.Text(relic.desc, { fontSize = 14, whiteSpace = "normal", lineHeight = 1.5 }),
        UI.Panel { gap = 6, children = actions },
    }, { padding = 10, gap = 9, borderColor = instance.status == "sold" and C.rule or C.gold })
end

local function collectionCard(relic, instance)
    local tags = {}
    if instance and instance.status ~= "sold" then
        table.insert(tags, Visual.Text("本局持有", { fontSize = 12, fontColor = C.primary, backgroundColor = C.selected, paddingHorizontal = 7, paddingVertical = 3, borderRadius = 3 }))
    elseif instance and instance.status == "sold" then
        table.insert(tags, Visual.Text("本局曾持有 · 已出售", { fontSize = 12, fontColor = C.danger, backgroundColor = C.paper, paddingHorizontal = 7, paddingVertical = 3, borderRadius = 3 }))
    end
    table.insert(tags, Visual.Text("已解锁 · 下局可按预算带入", { fontSize = 12, fontColor = C.primary, backgroundColor = C.selected, paddingHorizontal = 7, paddingVertical = 3, borderRadius = 3 }))
    return Visual.Card({
        UI.Row { gap = 10, alignItems = "center", children = {
            Visual.Relic(relic.id, 64),
            UI.Panel { flex = 1, minWidth = 0, gap = 3, children = {
                Visual.Text(relic.name, { fontSize = 16, fontWeight = "bold" }),
                UI.Row { gap = 5, flexWrap = "wrap", children = tags },
            } },
        } },
        Visual.Text("收藏资格已写入 Profile。\n来源 · " .. tostring(relic.story.source or "本局经历") .. "\n" .. relic.desc, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.45 }),
    }, { padding = 10, gap = 7, backgroundColor = C.paper, borderColor = C.rule })
end

function RelicsView.Build(app)
    if RelicState.IsNew(app.run) then return RelicV12View.Build(app) end
    local run = app.run
    local actual = {}
    local collection = {}
    for _, relic in ipairs(Data.Relics) do
        local instance = findInstance(run, relic.id)
        if instance then table.insert(actual, instanceCard(app, instance, relic)) end
        local unlocked = app.profile.unlockedRelicIds and app.profile.unlockedRelicIds[relic.id] == true
        if unlocked then table.insert(collection, collectionCard(relic, instance)) end
    end
    local cards = {
        Visual.Decor("branch_line", { width = "100%", height = 12, opacity = 0.42, pointerEvents = "none" }),
        Visual.Text("本局藏阁", { fontSize = 22, fontWeight = "bold" }),
        Visual.Text("每件物件都保留真实来源、保管人、执行人和后续；所有操作先确认，再进入本局账本与家史。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 }),
    }
    for _, card in ipairs(actual) do table.insert(cards, card) end
    if #actual == 0 then table.insert(cards, Visual.Card({ Visual.Text("本局尚未带入信物。", { fontSize = 15, fontColor = C.secondary }) }, { padding = 12 })) end
    if #collection > 0 then
        table.insert(cards, Visual.Text("已解锁信物 · 收藏资格", { fontSize = 19, fontWeight = "bold", marginTop = 8 }))
        table.insert(cards, Visual.Text("出售本局物件不会抹掉已解锁资格。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" }))
        for _, card in ipairs(collection) do table.insert(cards, card) end
    end
    return UI.Panel { gap = 10, paddingBottom = 10, children = cards }
end

return RelicsView
