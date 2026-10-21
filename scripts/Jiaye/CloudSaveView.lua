local UI = require "urhox-libs/UI"
local Visual = require "Jiaye.Visual"
local V7 = require "Jiaye.V7"
local Skin = require "Jiaye.QianjiajiSkin"
local State = require "Jiaye.State"
local ModalLayout = require "Jiaye.ModalLayout"

local View = {}
local C = V7.Colors

local function text(value, props)
    local p = props or {}
    p.width, p.whiteSpace, p.lineHeight = p.width or "100%", "normal", p.lineHeight or 1.6
    p.flexShrink = 0
    return Visual.Text(value, p)
end

local function timeLabel(timestamp)
    if not timestamp then return "未记录时间" end
    local today = os.date("%Y-%j", os.time()) == os.date("%Y-%j", timestamp)
    return os.date(today and "今天 %H:%M" or "%Y-%m-%d %H:%M", timestamp)
end

local function summary(payload)
    if not payload then return "尚无已保存家谱", "开始经营后，进度会自动保存。" end
    local draft, run = payload.draft, payload.run
    local family = tostring(draft.family) .. "氏家谱"
    if not run then return family .. " · 开局草案", "大晟历 " .. tostring(draft.calendar) .. " 年" end
    local living = 0
    for _, member in ipairs(run.members) do
        if member.alive ~= false and State.IsResident(member) then living = living + 1 end
    end
    return family .. " · 第 " .. tostring(run.yearIndex + 1) .. " 年",
        "大晟历 " .. tostring(run.calendar) .. " 年 · 家中 " .. tostring(living) .. " 人\n银 "
        .. tostring(run.money) .. " 两 · 粮 " .. tostring(run.grain) .. " 石"
end

function View.HasIssue(app)
    return app.cloud and app.cloud.ready and app.cloud.lastError ~= "" or false
end

function View.EntryText(app)
    return View.HasIssue(app) and "家谱存档 · 待同步" or "家谱存档"
end

local function status(app)
    local cloud = app.cloud
    if app.storageBlocked then return "本机家谱无法读取", "请先恢复可读取的家谱，再继续经营。" end
    if app.unsaved or (cloud and cloud.localWriteFailed) then
        return "本机保存失败", "最新安排尚未保存，请重试保存后再继续经营。"
    end
    if not cloud then
        if not fileSystem:HasPersistentFS() then return "仅保存在本次预览", "刷新或退出预览后，本次进度会丢失。" end
        return "仅保存在本机", app.loginMode == "guest" and "当前为游客登录，家谱保存在这台设备。" or "当前为本地开发，家谱保存在这台设备。"
    end
    if View.HasIssue(app) then
        local detail = fileSystem:HasPersistentFS() and "最新进度已保存在本机，正在自动重试。"
            or "进度保留在本次会话，刷新或退出前请完成云端同步。"
        return "等待云端同步", cloud.localPayload and detail or "云端暂时无法连接，正在自动重试。"
    end
    if cloud.busy or cloud.state == "pending" or cloud.state == "writing" then
        return "正在同步到云端", "本机已保存，正在核对并上传最新进度。"
    end
    if cloud.localPayload then return "已同步到云端", "本次进度已保存，可在其他设备续写。" end
    return "自动保存已开启", "开始经营后，进度将自动保存到当前 TapTap 账号。"
end

local function diagnostic(message, app)
    local detail = text(message, { id = "save-error-detail", fontSize = 13, fontColor = C.secondary, visible = app.saveErrorExpanded == true })
    return UI.Panel { id = "save-error", width = "100%", flexShrink = 0, children = {
        Skin.TextAction("查看错误详情 ›", function()
            app.saveErrorExpanded = not app.saveErrorExpanded
            detail:SetVisible(app.saveErrorExpanded)
        end, { id = "save-error-toggle", fontSize = 13, justifyContent = "flex-start" }), detail,
    } }
end

local function timestampRow(label, value)
    return UI.Row { width = "100%", gap = 12, alignItems = "flex-start", children = {
        Visual.Text(label, { width = 76, fontSize = 14, fontColor = C.secondary }),
        text(value, { flex = 1, minWidth = 0, fontSize = 14, textAlign = "right" }),
    } }
end

function View.Open(app)
    if app.storageBlocked or app.unsaved or (app.cloud and app.cloud.blocked) then app:Render(); return end
    if app.saveDetails then return end
    app.saveErrorExpanded = false
    local modal = ModalLayout.New("家谱存档", { sheet = "detail", contentPadding = { 12, 20 },
        onClose = function() app.saveDetails = nil end })
    local body = ModalLayout.Scroll(nil, { id = "save-details-content", gap = 18, children = {} })
    local action = Visual.Button("", function()
        if app.cloud then app:FlushCloud() else app:Save(true) end
    end, { id = "save-details-action", width = "100%", height = 48, role = "secondary" })
    local function refresh()
        body:RemoveAllChildren()
        local title, detail = status(app)
        body:AddChild(text(title, { id = "save-details-status", fontSize = 22, fontColor = View.HasIssue(app) and C.gold or C.primary }))
        body:AddChild(text(detail, { fontSize = 15, fontColor = C.secondary }))
        local payload = app.cloud and app.cloud.localPayload or State.Load()
        local family, description = summary(payload)
        body:AddChild(UI.Panel { width = "100%", paddingVertical = 18, gap = 8,
            borderTopWidth = 1, borderBottomWidth = 1, borderTopColor = C.rule, borderBottomColor = C.rule,
            children = { text(family, { fontSize = 23 }), text(description, { fontSize = 15, fontColor = C.secondary }) } })
        body:AddChild(timestampRow(fileSystem:HasPersistentFS() and "本机保存" or "会话保存", payload and timeLabel(payload.savedAt) or "尚未保存"))
        if app.cloud then
            local remote = app.cloud.remote
            body:AddChild(timestampRow("云端保存", remote and timeLabel(remote.updatedAt) or "尚未保存"))
            local sync = app.cloud.localPayload and app.cloud.localPayload.cloudSync
            if View.HasIssue(app) or (sync and sync.pendingRevision) then
                body:AddChild(text("换设备前，请等待云端同步完成。", { fontSize = 14, fontColor = C.danger }))
            end
            if app.cloud.lastError ~= "" then body:AddChild(diagnostic(app.cloud.lastError, app)) end
        else
            body:AddChild(text("换设备续玩需要使用 TapTap 账号云存档。", { fontSize = 14, fontColor = C.secondary }))
        end
        local busy = app.cloud and app.cloud.busy
        action:SetText(not app.cloud and (fileSystem:HasPersistentFS() and "保存到本机" or "保存本次进度") or (busy and "同步中…" or (View.HasIssue(app) and "重试同步" or "立即同步")))
        action:SetDisabled(busy == true)
    end
    app.saveDetails = { modal = modal, refresh = refresh }
    refresh()
    modal:AddContent(UI.Panel { width = "100%", height = "100%", gap = 14, children = {
        body, action,
        text("游戏会自动保存家谱进度", { fontSize = 13, fontColor = C.secondary, textAlign = "center" }),
    } })
    modal:Open()
end

function View.Notice(app)
    if not app.cloudNoticeUntil then return nil end
    local message = fileSystem:HasPersistentFS() and "进度已保存到本机\n云端暂未同步，正在重试。"
        or "进度已保留在本次会话\n云端暂未同步，请保持页面开启。"
    return UI.SafeAreaView { id = "save-cloud-notice", position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", edges = { "bottom", "left", "right" }, pointerEvents = "box-none", children = {
            UI.Panel { width = "100%", height = "100%", pointerEvents = "box-none", children = {
                UI.Panel { position = "absolute", left = 16, right = 16, bottom = 120, maxWidth = 480, alignSelf = "center",
                    padding = 12, borderWidth = 1, borderColor = C.rule, backgroundColor = C.paperLight, borderRadius = 4,
                    children = { UI.Row { width = "100%", alignItems = "center", gap = 8, children = {
                        text(message, { flex = 1, minWidth = 0, fontSize = 14 }),
                        Skin.TextAction("查看存档", function() app.cloudNoticeUntil = nil; View.Refresh(app); View.Open(app) end,
                            { id = "save-cloud-notice-open", width = 76, fontSize = 14 }),
                    } } },
                },
            } },
        } }
end

function View.Gate(app)
    local cloud = app.cloud
    local localFailure = app.unsaved or app.storageBlocked or (cloud and cloud.localWriteFailed)
    local conflict = cloud and cloud.conflict and not cloud.chooseCloud and not localFailure
    local title, detail = "正在取回家谱", "正在读取当前 TapTap 账号的云端进度，请稍候。"
    if localFailure then title, detail = status(app)
    elseif conflict then
        title, detail = "选择继续的家谱", "云端和本机的进度有变化。请核对家谱，选择这次要继续的一份。"
    elseif cloud.state == "invalid" then
        title, detail = "家谱暂时无法恢复", "家谱未通过内容校验，现有进度保持原样。请重新读取。"
    elseif cloud.state == "error" then
        title, detail = "暂时无法取回家谱", "暂时无法确认云端进度。已有家谱保持原样，请稍后重试。"
    elseif cloud.ready then
        title, detail = "正在确认所选家谱", "正在核对并同步所选进度，请稍候。"
    end
    ---@type Widget[]
    local content = { text("家谱存档", { fontSize = 14, fontColor = C.secondary }),
        text(title, { id = "save-gate-title", fontSize = 28 }),
        text(detail, { id = "save-gate-description", fontSize = 16, fontColor = C.secondary }) }
    if conflict then
        for _, choice in ipairs({ { true, "云端进度", cloud.remote and cloud.remote.payload, cloud.remote and cloud.remote.updatedAt },
            { false, "本机进度", cloud.localPayload, cloud.localPayload and cloud.localPayload.savedAt } }) do
            local useCloud, label, payload, savedAt = choice[1], choice[2], choice[3], choice[4]
            if payload then
                local selected = app.cloudChoice == useCloud
                local family, description = summary(payload)
                content[#content + 1] = UI.Panel { id = useCloud and "cloud-save-use-remote" or "cloud-save-use-local",
                    width = "100%", padding = 16, gap = 9, pointerEvents = "box-only",
                    borderWidth = 1, borderColor = selected and C.primary or C.rule,
                    backgroundColor = selected and C.selected or C.paperLight,
                    onClick = function() app.cloudChoice = useCloud; app:Render() end, children = {
                        UI.Row { width = "100%", justifyContent = "space-between", alignItems = "center", children = {
                            Visual.Text(label, { fontSize = 14, fontColor = C.secondary }), Skin.Icon(selected and "radio_on" or "radio_off", 22),
                        } },
                        text(family, { fontSize = 22 }), text(description, { fontSize = 14, fontColor = C.secondary }),
                        text(timeLabel(savedAt) .. " 保存", { fontSize = 13, fontColor = C.secondary }),
                    } }
            end
        end
    end
    local issue = (app.unsaved or app.storageBlocked) and app.saveMessage or (cloud and cloud.lastError)
    if issue and issue ~= "" then content[#content + 1] = diagnostic(issue, app) end
    local footer = {}
    if conflict then
        footer[#footer + 1] = text(app.cloudChoice == nil and "确认前，两份进度均保持原样。"
            or ("确认后，将以" .. (app.cloudChoice and "云端" or "本机") .. "进度续玩，并同步到当前账号。"),
            { fontSize = 14, fontColor = C.secondary })
        footer[#footer + 1] = Visual.Button(app.cloudChoice == nil and "选择一份家谱后继续"
            or ("续写" .. (app.cloudChoice and "云端" or "本机") .. "家谱"), function()
                if app.cloudChoice ~= nil and not cloud.busy then cloud:Resolve(app.cloudChoice) end
            end, { id = "cloud-save-confirm", width = "100%", height = 48, disabled = app.cloudChoice == nil or cloud.busy })
    elseif localFailure or cloud.state == "error" or cloud.state == "invalid" then
        footer[#footer + 1] = Visual.Button(localFailure and (app.storageBlocked and "重新读取" or "重试保存") or "重新读取", function()
            if app.storageBlocked then app:Load()
            elseif app.unsaved then app:Save()
            else app:FlushCloud() end
        end, { id = "cloud-save-retry", width = "100%", height = 48, disabled = cloud and cloud.busy or false })
    else
        footer[#footer + 1] = text(cloud.ready and "确认完成后继续游戏" or "读取完成后继续游戏", { fontSize = 14, fontColor = C.secondary, textAlign = "center" })
    end
    if app.loginMode then
        footer[#footer + 1] = Visual.Button("切换登录方式", function() app:ShowLogin() end, {
            id = "cloud-save-switch-login", width = "100%", height = 48, role = "secondary",
        })
    end
    return UI.SafeAreaView { id = "save-gate", width = "100%", height = "100%", edges = "all", nativeMenuInset = true,
        backgroundColor = C.paper, pointerEvents = "box-none", children = {
            UI.Panel { width = "100%", maxWidth = 520, height = "100%", alignSelf = "center", padding = 24, gap = 20,
                children = { ModalLayout.Scroll(nil, { id = "save-gate-content", gap = 18, children = content }),
                    UI.Panel { id = "save-gate-footer", width = "100%", gap = 12, children = footer } } },
        } }
end

function View.Refresh(app)
    if app.saveDetails then app.saveDetails.refresh() end
    if app.saveMenuButton then app.saveMenuButton:SetText(View.EntryText(app)) end
    if not app.root then return end
    local entry = app.root:FindById("cover-save-label") --[[@as Label?]]
    if entry then entry:SetText(View.EntryText(app)) end
    local indicator = app.root:FindById("cloud-save-indicator")
    if indicator then indicator:SetVisible(View.HasIssue(app)) end
    local notice = app.root:FindById("save-cloud-notice")
    if notice then notice:SetVisible(app.cloudNoticeUntil ~= nil) end
end

return View
