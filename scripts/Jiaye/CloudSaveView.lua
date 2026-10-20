local UI = require "urhox-libs/UI"
local Visual = require "Jiaye.Visual"
local V7 = require "Jiaye.V7"

local View = {}
local C = V7.Colors

local function summary(payload)
    if not payload then return "尚无家谱" end
    local run = payload.run
    return tostring(payload.draft.family) .. "氏 · " .. (run and ("第 " .. tostring(run.yearIndex + 1) .. " 年") or "开局草案")
        .. (run and ("\n大晟历 " .. tostring(run.calendar) .. " 年 · 银 " .. tostring(run.money) .. " 两 · 粮 " .. tostring(run.grain) .. " 石") or "")
end

function View.Status(app)
    local cloud = app.cloud
    app.cloudStatusLabel = Visual.Text(cloud.message, {
        id = "cloud-save-status", flex = 1, minWidth = 0, fontSize = 12,
        fontColor = cloud.state == "error" and C.danger or C.secondary,
        whiteSpace = "normal", lineHeight = 1.4,
    })
    app.cloudRetryButton = Visual.Button("同步", function() app:FlushCloud() end, {
        id = "cloud-save-retry", height = 44, width = 64, role = "secondary", disabled = cloud.busy,
    })
    return UI.Row { paddingHorizontal = 12, paddingVertical = 4, gap = 8, alignItems = "center",
        backgroundColor = C.paperLight, children = { app.cloudStatusLabel, app.cloudRetryButton } }
end

function View.Gate(app)
    local cloud = app.cloud
    local children = {
        Visual.Text(cloud.conflict and "选择继续的家谱" or "账号家谱", {
            width = "100%", fontSize = 26, fontFamily = "serif", fontColor = C.primary,
        }),
    }
    app.cloudGateLabel = Visual.Text(cloud.message, { width = "100%", fontSize = 16, whiteSpace = "normal", lineHeight = 1.6 })
    table.insert(children, app.cloudGateLabel)
    if cloud.conflict then
        table.insert(children, Visual.Text("选择后将继续所选进度，并同步到当前 TapTap 账号。", {
            width = "100%", fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5,
        }))
        if cloud.remote then
            table.insert(children, Visual.Card({
                Visual.Text("云端家谱", { fontSize = 18 }),
                Visual.Text(summary(cloud.remote.payload), { whiteSpace = "normal", lineHeight = 1.5 }),
                Visual.Button("使用云端进度", function() cloud:Resolve(true) end, { id = "cloud-save-use-remote", width = "100%", height = 48 }),
            }))
        end
        if cloud.localPayload then
            table.insert(children, Visual.Card({
                Visual.Text("本机家谱", { fontSize = 18 }),
                Visual.Text(summary(cloud.localPayload), { whiteSpace = "normal", lineHeight = 1.5 }),
                Visual.Button("使用本机进度", function() cloud:Resolve(false) end, {
                    id = "cloud-save-use-local", width = "100%", height = 48, role = "secondary",
                }),
            }))
        end
    end
    app.cloudRetryButton = Visual.Button("重新连接", function() cloud:Retry() end, {
        id = "cloud-save-retry", width = "100%", height = 48, role = "secondary", disabled = cloud.busy,
    })
    table.insert(children, app.cloudRetryButton)
    return UI.SafeAreaView { width = "100%", height = "100%", edges = "all", nativeMenuInset = true, backgroundColor = C.paper,
        children = { UI.ScrollView { width = "100%", height = "100%", padding = 24, children = {
            UI.Panel { width = "100%", maxWidth = 520, alignSelf = "center", gap = 16, children = children },
        } } } }
end

function View.Refresh(app)
    local cloud = app.cloud
    if app.cloudStatusLabel then
        app.cloudStatusLabel:SetText(cloud.message)
        app.cloudStatusLabel:SetStyle({ fontColor = cloud.state == "error" and C.danger or C.secondary })
    end
    if app.cloudGateLabel then app.cloudGateLabel:SetText(cloud.message) end
    if app.cloudRetryButton then app.cloudRetryButton:SetDisabled(cloud.busy) end
end

return View
