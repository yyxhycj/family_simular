local UI = require "urhox-libs/UI"
local Visual = require "Jiaye.Visual"
local V7 = require "Jiaye.V7"

local View = {}
local C = V7.Colors

function View.Build(app)
    local desktop = GetPlatform() == "macOS" or GetPlatform() == "Windows" or GetPlatform() == "Linux"
    local path = desktop and "image/taptap/login-pc.png" or "image/taptap/login-mobile.png"
    local texture = assert(cache:GetResource("Texture2D", path), "TapTap 登录按钮资源缺失。")
    local width = math.min(desktop and 370 or 270, UI.GetWidth() - 80)
    return UI.Panel {
        id = "login-screen", width = "100%", height = "100%", backgroundColor = C.paper,
        children = {
            Visual.OpeningArt("landscape", { position = "absolute", width = "100%", height = "100%" }),
            UI.SafeAreaView { width = "100%", height = "100%", edges = "all", nativeMenuInset = true, children = {
                UI.ScrollView { width = "100%", height = "100%", children = {
                    UI.Panel { width = "100%", minHeight = UI.GetHeight(), padding = 24, justifyContent = "center", alignItems = "center", children = {
                        UI.Panel { width = "100%", maxWidth = 450, padding = 16, gap = 18, alignItems = "center",
                            backgroundColor = { 251, 245, 229, 248 }, borderRadius = 8, children = {
                                Visual.Text("千家纪", { width = "100%", fontSize = 42, fontFamily = "serif", textAlign = "center" }),
                                Visual.Text("选择登录方式", { width = "100%", fontSize = 20, textAlign = "center" }),
                                UI.Panel {
                                    id = "login-taptap", width = width, height = width * texture.height / texture.width,
                                    padding = 0, borderWidth = 0, borderRadius = 0,
                                    backgroundImage = path, backgroundFit = "contain", pointerEvents = "auto",
                                    onClick = function() app:LoginTapTap() end,
                                },
                                Visual.Button("游客登录", function() app:LoginGuest() end, { id = "login-guest", width = "100%", height = 50, role = "secondary" }),
                                Visual.Text(app.loginMessage, { id = "login-message", width = "100%", fontSize = 14,
                                    fontColor = C.danger, textAlign = "center", whiteSpace = "normal", lineHeight = 1.5,
                                    visible = app.loginMessage ~= "",
                                }),
                            },
                        },
                    } },
                } },
            } },
        },
    }
end

function View.Status(app)
    return UI.Panel { width = "100%", gap = 8, children = {
        Visual.Text(app.loginMode == "taptap" and "TapTap 账号 · 云存档" or "游客登录 · 仅本机存档", {
            id = "login-status", width = "100%", fontSize = 14, fontColor = C.secondary, whiteSpace = "normal",
        }),
        Visual.Button("切换登录方式", function() app:ShowLogin() end, { id = "login-switch", width = "100%", height = 46, role = "secondary" }),
    } }
end

return View
