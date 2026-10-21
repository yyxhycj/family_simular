local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local Art = require "Jiaye.Art"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"
local CloudSaveView = require "Jiaye.CloudSaveView"
local Skin = require "Jiaye.QianjiajiSkin"

local View = {}
local C = V7.Colors

local function menuEntry(id, text, onClick, primary)
    return UI.Button {
        id = id, width = "100%", height = primary and 72 or 48,
        padding = 0, borderWidth = 0, borderRadius = 0, opacity = 0.94,
        backgroundColor = { 0, 0, 0, 0 },
        hoverBackgroundColor = { 0, 0, 0, 0 }, pressedBackgroundColor = { 0, 0, 0, 0 },
        boxShadow = false, hoverBoxShadow = false, pressedBoxShadow = false,
        alignItems = "center", justifyContent = "center", onClick = onClick,
        onPointerEnter = function(_, widget) widget:SetOpacity(1) end,
        onPointerLeave = function(_, widget) widget:SetOpacity(0.94) end,
        onPointerDown = function(_, widget) widget:SetOpacity(0.6) end,
        onPointerUp = function(_, widget) widget:SetOpacity(1) end,
        onPointerCancel = function(_, widget) widget:SetOpacity(0.94) end,
        children = {
            Visual.Text(text, {
                id = id == "cover-save" and "cover-save-label" or nil,
                width = "100%", fontSize = primary and 34 or 21,
                fontFamily = "serif", letterSpacing = primary and 4 or 2,
                fontColor = primary and { 255, 244, 213, 255 } or { 235, 222, 193, 255 },
                textAlign = "center", whiteSpace = "nowrap", pointerEvents = "none",
                textShadow = { offsetX = 0, offsetY = 2, blur = 5, color = { 14, 29, 24, 200 } },
            }),
        },
    }
end

local function worldRegion(app, world, masked)
    local selected = app.coverWorldId == world.id
    local ink = masked and C.paperLight or C.primary
    return UI.Button {
        id = "cover-world-" .. world.id, text = "",
        position = "absolute", paddingHorizontal = 0, paddingVertical = 0,
        minWidth = 0, minHeight = 0, borderRadius = 0,
        backgroundColor = { 255, 249, 235, 0 },
        hoverBackgroundColor = { 255, 249, 235, 34 }, pressedBackgroundColor = { 255, 249, 235, 58 },
        borderWidth = selected and 1 or 0, borderColor = C.gold,
        boxShadow = false, hoverBoxShadow = false, pressedBoxShadow = false,
        onClick = function() app:SelectCoverWorld(world.id) end,
        onPointerDown = function(_, widget) widget:SetOpacity(0.8) end,
        onPointerUp = function(_, widget) widget:SetOpacity(1) end,
        onPointerCancel = function(_, widget) widget:SetOpacity(1) end,
        children = {
            UI.Panel {
                position = "absolute", left = 0, bottom = 14, width = "100%",
                gap = 4, alignItems = "center", pointerEvents = "none",
                children = {
                    Visual.Text(world.name, { width = "100%", fontSize = 18, fontFamily = "serif", fontColor = ink, textAlign = "center", whiteSpace = "normal", wordBreak = "break-word", lineHeight = 1.2 }),
                    Visual.Text(world.available and world.title or "未开放", { width = "100%", fontSize = 11, fontColor = ink, textAlign = "center", whiteSpace = "nowrap", lineHeight = 1.3 }),
                    UI.Panel { width = 28, height = 2, visible = selected, backgroundColor = ink },
                },
            },
        },
    }
end

local function worldRegions(app, image, masked, painted)
    local regions = {}
    for _, world in ipairs(Data.Worlds) do
        table.insert(regions, painted and UI.Panel {
            id = "cover-world-art-" .. world.id, position = "absolute",
            backgroundImage = Art.WorldScene(world.id), backgroundFit = "cover",
            backgroundImageOpacity = 0.64, pointerEvents = "none",
        } or worldRegion(app, world, masked))
    end
    local layer = UI.Panel {
        id = painted and "cover-world-paintings" or "cover-world-regions", position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", pointerEvents = painted and "none" or "box-none", children = regions,
    }
    local lastWidth, lastHeight = 0, 0
    layer.Update = function(self)
        local rect = self:GetLayout()
        if rect.w == lastWidth and rect.h == lastHeight then return end
        lastWidth, lastHeight = rect.w, rect.h
        -- 沿用原山河图的右上长幅区域，六个入口平分屏幕内可见宽度。
        local scale = math.max(rect.w / image.width, rect.h / image.height)
        local offsetX, offsetY = (rect.w - image.width * scale) / 2, (rect.h - image.height * scale) / 2
        local startX = math.max(0, 400 * scale + offsetX)
        local regionWidth = (rect.w - startX) / #regions
        for index, region in ipairs(regions) do
            local bottom = math.min(rect.h, (660 + (index - 1) * 28) * scale + offsetY)
            local top = math.max(0, offsetY)
            region:SetVisible(bottom > top)
            region:SetStyle({ left = startX + (index - 1) * regionWidth, top = top, width = regionWidth, height = math.max(0, bottom - top) })
        end
    end
    return layer
end

local function comingSoon(app, world)
    return UI.Panel {
        id = "cover-world-mask", position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", backgroundColor = { 24, 39, 35, 172 },
        borderRadius = 0, pointerEvents = "auto",
        children = {
            UI.SafeAreaView { width = "100%", height = "100%", edges = "all", nativeMenuInset = true, children = {
                Skin.BackAction(function() app:SelectCoverWorld("mortal") end, {id = "cover-return-mortal", position = "absolute", top = 0, left = 20}),
                UI.Panel { width = "100%", height = "100%", padding = 28, paddingTop = 180, alignItems = "center", justifyContent = "center", pointerEvents = "box-none", children = {
                    UI.Panel {
                        width = "100%", maxWidth = 360, padding = 28, gap = 14, alignItems = "center",
                        backgroundColor = { 251, 245, 229, 246 }, borderWidth = 1, borderColor = C.gold, borderRadius = 4,
                        children = {
                            Visual.Text(world.name, { width = "100%", fontSize = 20, fontFamily = "serif", fontColor = C.primary, textAlign = "center" }),
                            UI.Panel { width = 36, height = 1, backgroundColor = C.gold, pointerEvents = "none" },
                            Visual.Text("敬请期待", { id = "cover-coming-soon", width = "100%", fontSize = 36, fontFamily = "serif", textAlign = "center", whiteSpace = "nowrap" }),
                            Visual.Text("该世界尚未开放", { width = "100%", fontSize = 15, fontColor = C.secondary, textAlign = "center" }),
                        },
                    },
                } },
            } },
        },
    }
end

function View.Build(app)
    local world = assert(Data.Find(Data.Worlds, app.coverWorldId), "主页世界未登记。")
    local image = assert(cache:GetResource("Texture2D", Art.Opening("landscape")), "主页背景图片缺失。")
    local actions = {}
    if world.available then
        table.insert(actions, menuEntry("cover-new-family", "立一部家谱", function() app:PrepareNewRun() end, true))
        if app.run then table.insert(actions, menuEntry("cover-continue", "续写当前家谱", function() app:Load() end, false)) end
        table.insert(actions, menuEntry("cover-achievements", "成就", function() app:OpenAchievements() end, false))
        table.insert(actions, menuEntry("cover-save", CloudSaveView.EntryText(app), function() app:OpenSaveDetails() end, false))
        if app.loginMode then
            table.insert(actions, menuEntry("cover-account", app.loginMode == "taptap" and "TapTap · 账号云存档" or "游客 · 仅本机存档", function() app:ShowLogin() end, false))
        end
        if app.openingGenerationFailed then
            table.insert(actions, 1, Visual.Text(app.openingFeedback, { width = "100%", fontSize = 14, fontColor = { 255, 196, 172, 255 }, textAlign = "center", whiteSpace = "normal", lineHeight = 1.5 }))
        end
    end
    return UI.Panel {
        id = "cover", width = "100%", height = "100%", overflow = "hidden", backgroundColor = C.paper,
        children = {
            Visual.OpeningArt("landscape", { id = "cover-background", position = "absolute", left = 0, top = 0, width = "100%", height = "100%" }),
            worldRegions(app, image, false, true),
            UI.Panel {
                position = "absolute", left = 0, top = 0, width = "100%", height = "100%", pointerEvents = "none",
                backgroundGradient = { type = "linear", direction = "to-bottom", from = { 247, 240, 223, 72 }, to = { 247, 240, 223, 12 } },
            },
            UI.Panel {
                id = "cover-menu-shade", position = "absolute", left = 0, bottom = 0,
                width = "100%", height = "42%", borderRadius = 0, pointerEvents = "none", visible = world.available,
                backgroundGradient = { type = "linear", direction = "to-bottom", from = { 25, 43, 36, 0 }, to = { 25, 43, 36, 232 } },
            },
            UI.SafeAreaView {
                width = "100%", height = "100%", edges = "all", nativeMenuInset = true, children = {
                    UI.Panel { width = "100%", height = "100%", alignItems = "center", pointerEvents = "box-none", children = {
                        UI.Panel { width = "100%", maxWidth = 640, height = "100%", padding = 24, gap = 20,
                            overflow = "scroll", pointerEvents = "box-none", children = {
                                UI.Row { width = "100%", gap = 8, alignItems = "center", pointerEvents = "none", children = {
                                    Visual.Decor("seal_square", { width = 26, height = 26 }),
                                    Visual.Text("世界 · " .. (world.title or world.name), { id = "cover-world-name", fontSize = 16, fontColor = C.primary }),
                                } },
                                UI.Panel { id = "cover-hero", width = "100%", gap = 10, paddingTop = 22, pointerEvents = "none", children = {
                                    Visual.Text("千家纪", { id = "cover-title", width = "100%", fontSize = 64, fontWeight = "bold", fontFamily = "serif", letterSpacing = 4, whiteSpace = "nowrap", textShadow = { offsetX = 1, offsetY = 2, blur = 2, color = { 255, 249, 235, 180 } } }),
                                    Visual.Text(world.tagline, { id = "cover-tagline", width = "100%", fontSize = 20, fontColor = C.primary, fontFamily = "serif", whiteSpace = "normal", lineHeight = 1.5 }),
                                } },
                                UI.Panel { flexGrow = 1, flexBasis = 0, minHeight = 24, pointerEvents = "none" },
                                world.available and UI.Panel { id = "cover-actions", width = "100%", alignItems = "center", gap = 16, paddingBottom = 12, pointerEvents = "box-none", children = {
                                    UI.Panel { width = "100%", maxWidth = 360, gap = 2, children = actions },
                                    UI.Panel { width = 36, height = 1, backgroundColor = { 221, 198, 147, 140 }, pointerEvents = "none" },
                                    Visual.Text(world.heading, { id = "cover-heading", width = "100%", fontSize = 13, fontFamily = "serif", letterSpacing = 1, fontColor = { 235, 222, 193, 190 }, textAlign = "center", whiteSpace = "normal", pointerEvents = "none" }),
                                } } or UI.Panel { width = 0, height = 0, pointerEvents = "none" },
                            },
                        },
                    } },
                },
            },
            world.available and UI.Panel { width = 0, height = 0, pointerEvents = "none" } or comingSoon(app, world),
            worldRegions(app, image, not world.available),
        },
    }
end

return View
