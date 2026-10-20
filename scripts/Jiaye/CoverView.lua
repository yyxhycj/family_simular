local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local Art = require "Jiaye.Art"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"

local View = {}
local C = V7.Colors
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 112, 300, 24

local function entryButton(id, text, onClick, secondary)
    local skin = secondary and "secondary" or "primary"
    return UI.Button {
        id = id, text = text, width = "100%", height = 50, minHeight = 50,
        fontSize = 20, fontFamily = "serif", borderWidth = 0, borderRadius = 0,
        textColor = secondary and C.primary or C.paperLight,
        backgroundColor = { 0, 0, 0, 0 },
        hoverBackgroundColor = { 0, 0, 0, 0 }, pressedBackgroundColor = { 0, 0, 0, 0 },
        backgroundImage = Art.WorldEntry(skin),
        hoverBackgroundImage = Art.WorldEntry(skin .. "Focus"),
        pressedBackgroundImage = Art.WorldEntry(skin .. "Pressed"),
        backgroundFit = "sliced", backgroundSlice = { left = 24, top = 24, right = 24, bottom = 24 },
        boxShadow = false, hoverBoxShadow = false, pressedBoxShadow = false,
        onClick = onClick,
    }
end

local function worldCard(app, world)
    local selected = app.coverWorldId == world.id
    local normalFrame = Art.WorldEntry(selected and "frameSelected" or "frameDefault")
    local frame = UI.Panel {
        id = "cover-frame-" .. world.id, position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", backgroundImage = normalFrame,
        backgroundFit = "contain", pointerEvents = "none",
    }
    return UI.Button {
        id = "cover-world-" .. world.id, width = CARD_WIDTH, height = 360, flexShrink = 0,
        paddingHorizontal = 0, paddingVertical = 0, gap = 10,
        flexDirection = "column", alignItems = "center", justifyContent = "flex-start",
        backgroundColor = { 0, 0, 0, 0 }, hoverBackgroundColor = { 0, 0, 0, 0 },
        pressedBackgroundColor = { 0, 0, 0, 0 }, borderWidth = 0, borderRadius = 0,
        boxShadow = false, hoverBoxShadow = false, pressedBoxShadow = false,
        onClick = function() app:SelectCoverWorld(world.id) end,
        onPointerEnter = function() frame:SetStyle({ backgroundImage = Art.WorldEntry("frameFocus") }) end,
        onPointerLeave = function() frame:SetStyle({ backgroundImage = normalFrame }) end,
        onPointerDown = function() frame:SetStyle({ backgroundImage = Art.WorldEntry("framePressed") }) end,
        onPointerUp = function() frame:SetStyle({ backgroundImage = normalFrame }) end,
        onPointerCancel = function() frame:SetStyle({ backgroundImage = normalFrame }) end,
        children = {
            Visual.Text(world.name, { width = "100%", height = 24, fontSize = 20, fontFamily = "serif", fontColor = C.primary, textAlign = "center", whiteSpace = "nowrap", pointerEvents = "none" }),
            UI.Panel {
                id = "cover-scene-" .. world.id, width = CARD_WIDTH, height = CARD_HEIGHT, flexShrink = 0,
                backgroundImage = Art.WorldScene(world.id), backgroundFit = "contain", pointerEvents = "none",
                children = { frame },
            },
            Visual.Text(selected and "已选世界" or (world.available and "可进入" or "未开放"), {
                width = "100%", height = 16, fontSize = 12, textAlign = "center",
                fontColor = selected and C.primary or C.secondary, whiteSpace = "nowrap", pointerEvents = "none",
            }),
        },
    }
end

local function worldGallery(app, selectedIndex)
    local cards = {}
    for _, world in ipairs(Data.Worlds) do table.insert(cards, worldCard(app, world)) end
    local gallery = UI.ScrollView {
        id = "cover-world-gallery", width = "100%", height = 372, flexShrink = 0,
        scrollX = true, scrollY = false, bounces = false, showScrollbar = true,
        children = { UI.Row { gap = CARD_GAP, flexShrink = 0, children = cards } },
    }
    ---@type fun(self: ScrollView, dt: number)
    local update = gallery.Update
    local lastWidth = 0
    ---@param dt number
    function gallery:Update(dt)
        update(self, dt)
        local width = self:GetLayout().w
        if width <= 0 or width == lastWidth then return end
        lastWidth = width
        self:UpdateContentSize()
        self:SetScroll((selectedIndex - 1) * (CARD_WIDTH + CARD_GAP) - (width - CARD_WIDTH) / 2, 0)
    end
    return gallery
end

local function worldDetails(app, world)
    local actions = {}
    if world.available then
        if app.openingGenerationFailed then
            table.insert(actions, Visual.Text(app.openingFeedback, { width = "100%", fontSize = 14, fontColor = C.danger, whiteSpace = "normal" }))
        end
        table.insert(actions, entryButton("cover-new-family", "立一部家谱", function() app:PrepareNewRun() end))
        if app.run then table.insert(actions, entryButton("cover-continue", "续写当前家谱", function() app:Load() end, true)) end
    end
    return UI.Panel {
        id = "cover-details", width = "100%", minHeight = 230, padding = 22, gap = 14,
        backgroundImage = Art.WorldEntry("panel"), backgroundFit = "sliced",
        backgroundSlice = { left = 28, top = 28, right = 28, bottom = 28 },
        children = {
            UI.Row { width = "100%", alignItems = "center", gap = 10, children = {
                UI.Panel { id = "cover-world-icon", width = 28, height = 28, backgroundImage = Art.WorldIcon(world.id), backgroundFit = "contain", pointerEvents = "none" },
                Visual.Text(world.name .. (world.title and " · " .. world.title or ""), { id = "cover-world-name", fontSize = 24, fontFamily = "serif", fontColor = C.primary }),
            } },
            Visual.Text(world.available and world.heading or world.tagline, { id = "cover-heading", width = "100%", fontSize = 19, fontFamily = "serif", whiteSpace = "normal" }),
            Visual.Text(world.description, { id = "cover-description", width = "100%", fontSize = 14, lineHeight = 1.5, fontColor = C.secondary, whiteSpace = "normal" }),
            UI.Panel { id = "cover-actions", width = "100%", maxWidth = 440, alignSelf = "center", gap = 10, children = actions },
            not world.available and UI.Panel {
                id = "cover-world-mask", position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
                padding = 20, gap = 12, alignItems = "center", justifyContent = "center",
                backgroundColor = { 242, 235, 218, 238 }, borderRadius = 0,
                children = {
                    Visual.Text(world.name, { width = "100%", fontSize = 17, fontColor = C.primary, textAlign = "center" }),
                    Visual.Text("敬请期待", { id = "cover-coming-soon", width = "100%", fontSize = 36, fontFamily = "serif", textAlign = "center", whiteSpace = "nowrap" }),
                    Visual.Text("该世界尚未开放", { width = "100%", fontSize = 14, fontColor = C.secondary, textAlign = "center" }),
                    UI.Panel { width = "100%", maxWidth = 260, children = {
                        entryButton("cover-return-mortal", "返回凡世", function() app:SelectCoverWorld("mortal") end, true),
                    } },
                },
            } or UI.Panel { width = 0, height = 0, pointerEvents = "none" },
        },
    }
end

function View.Build(app)
    local world = assert(Data.Find(Data.Worlds, app.coverWorldId), "主页世界未登记。")
    local selectedIndex = 1
    for index, entry in ipairs(Data.Worlds) do if entry.id == world.id then selectedIndex = index end end
    return UI.Panel {
        id = "cover", width = "100%", height = "100%", backgroundColor = C.paper,
        backgroundImage = Art.WorldEntry("paper"), backgroundFit = "cover",
        children = {
            UI.SafeAreaView { width = "100%", height = "100%", edges = "all", nativeMenuInset = true, children = {
                UI.ScrollView { id = "cover-page-scroll", width = "100%", flexGrow = 1, flexBasis = 0, scrollX = false, showScrollbar = false, children = {
                    UI.Panel { width = "100%", alignItems = "center", padding = 24, children = {
                        UI.Panel { width = "100%", maxWidth = 792, gap = 18, children = {
                            UI.Row { width = "100%", alignItems = "center", justifyContent = "space-between", children = {
                                Visual.Text("千家纪", { id = "cover-title", fontSize = 42, fontWeight = "bold", fontFamily = "serif", letterSpacing = 4, whiteSpace = "nowrap" }),
                                Visual.Decor("seal_square", { width = 28, height = 28 }),
                            } },
                            Visual.Text("一姓起笔，百年成卷", { id = "cover-tagline", width = "100%", fontSize = 17, fontFamily = "serif", fontColor = C.secondary }),
                            UI.Row { width = "100%", alignItems = "center", justifyContent = "space-between", gap = 8, children = {
                                Visual.Text("选择世界", { fontSize = 16, fontFamily = "serif", fontColor = C.primary }),
                                UI.Row { gap = 8, alignItems = "center", children = {
                                    UI.Button { id = "cover-world-previous", text = "‹", width = 44, height = 44, paddingHorizontal = 0, paddingVertical = 0, variant = "secondary", onClick = function() app:SelectCoverWorld(Data.Worlds[(selectedIndex - 2) % #Data.Worlds + 1].id) end },
                                    Visual.Text(tostring(selectedIndex) .. " / " .. tostring(#Data.Worlds), { fontSize = 13, fontColor = C.secondary }),
                                    UI.Button { id = "cover-world-next", text = "›", width = 44, height = 44, paddingHorizontal = 0, paddingVertical = 0, variant = "secondary", onClick = function() app:SelectCoverWorld(Data.Worlds[selectedIndex % #Data.Worlds + 1].id) end },
                                } },
                            } },
                            worldGallery(app, selectedIndex),
                            worldDetails(app, world),
                        } },
                    } },
                } },
            } },
        },
    }
end

return View
