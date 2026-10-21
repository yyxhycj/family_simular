local UI = require "urhox-libs/UI"
local Theme = require "urhox-libs/UI/Core/Theme"
local V7 = require "Jiaye.V7"
local Art = require "Jiaye.Art"
local Skin = require "Jiaye.QianjiajiSkin"

local Visual = {}

local Tokens = V7.Tokens or {
    title = 29, panelTitle = 23, body = 16, control = 15, secondary = 13,
    border = 1, doubleFrameGap = 3, buttonRadius = 3, panelRadius = 10,
    sheetTopRadius = 12, primaryHeight = 48, touchMin = 44,
    pageInset = 17, sectionGap = 14,
}

local function copyProps(props)
    local copied = {}
    for key, value in pairs(props or {}) do copied[key] = value end
    return copied
end

local function childrenOf(children)
    if children == nil then return {} end
    if type(children) == "table" and children[1] ~= nil then return children end
    return { children }
end

local function requireAsset(path, message)
    assert(type(path) == "string" and path ~= "", message or "V7 资源路径为空。")
    return path
end

function Visual.Theme()
    local c = V7.Colors
    return Theme.ExtendTheme(Theme.defaultTheme, {
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/Qianjiaji/QianjiajiSong-Regular.ttf",
                bold = "Fonts/Qianjiaji/QianjiajiSong-Semibold.ttf",
            }},
            { family = "serif", weights = {
                normal = "Fonts/Qianjiaji/QianjiajiSong-Regular.ttf",
                bold = "Fonts/Qianjiaji/QianjiajiSong-Semibold.ttf",
            }},
            { family = Skin.FontFamily, weights = {
                normal = "Fonts/Qianjiaji/QianjiajiSong-Regular.ttf",
                bold = "Fonts/Qianjiaji/QianjiajiSong-Semibold.ttf",
            }},
        },
        typography = {
            fontFamily = Skin.FontFamily,
        },
        colors = {
            primary = c.primary, primaryHover = c.primary, primaryPressed = c.pressed,
            primaryDeep = c.pressed, primaryShadow = c.pressed,
            secondary = c.paperLight, secondaryHover = c.selected, secondaryPressed = c.rule,
            background = c.paper, surface = c.paperLight, surfaceAlt = c.paper,
            surfaceRaised = c.paperLight, text = c.ink, textSecondary = c.secondary,
            textMuted = c.secondary, textPlaceholder = c.secondary, textInverse = c.paperLight,
            border = c.rule, borderStrong = c.gold, borderFocus = c.gold,
            divider = c.rule, disabled = c.disabledSurface, disabledBorder = c.rule,
            disabledText = c.disabledInk, success = c.primary, successHover = c.primary,
            successPressed = c.pressed, successShadow = c.pressed,
            warning = c.gold, error = c.danger, errorHover = c.danger,
            errorPressed = c.pressed, errorShadow = c.danger, danger = c.danger,
            dangerHover = c.danger, dangerPressed = c.pressed,
            overlay = { 24, 43, 33, 112 }, infoSoft = c.selected,
            successSoft = c.selected, warningSoft = { 246, 239, 215, 255 },
            dangerSoft = { 247, 229, 221, 255 }, surfaceTooltip = c.ink,
            borderTooltip = c.gold,
        },
        radius = {
            none = 0, xs = 2, sm = Tokens.buttonRadius, md = Tokens.panelRadius,
            lg = Tokens.sheetTopRadius, full = 999,
        },
        componentDefaults = {
            borderRadius = Tokens.panelRadius,
        },
        components = {
            Button = {
                borderRadius = Tokens.buttonRadius, height = Tokens.primaryHeight,
                fontSize = V7.Font(Tokens.control), fontWeight = "normal", borderWidth = 0,
                paddingHorizontal = 19, paddingVertical = 9,
            },
            Card = {
                borderWidth = Tokens.border, borderRadius = Tokens.panelRadius,
                boxShadow = { { x = 0, y = 2, blur = 6, color = { 20, 43, 33, 14 } } },
            },
            Modal = {
                titleFontSize = V7.Font(Tokens.panelTitle),
                fontFamily = "serif",
                backgroundColor = c.paperLight, borderColor = c.gold,
                borderWidth = Tokens.border, borderRadius = Tokens.sheetTopRadius,
                titleTextColor = c.ink, closeIconColor = c.ink,
                headerBorderColor = c.rule, footerBorderColor = c.rule,
            },
            TextField = {
                fontSize = V7.Font(16),
                backgroundColor = c.paperLight, textColor = c.ink,
                borderColor = c.rule, focusedBorderColor = c.gold,
                focusedBgColor = c.selected,
                borderWidth = Tokens.border, borderRadius = Tokens.buttonRadius,
            },
            Dropdown = {
                fontSize = V7.Font(Tokens.control),
                triggerBgColor = c.paperLight, textColor = c.ink,
                borderColor = c.rule, openBorderColor = c.gold,
                popupBgColor = c.paperLight, popupBorderColor = c.gold,
                itemHoverBgColor = c.selected, itemSelectedColor = c.selected,
            },
            Tabs = {
                backgroundColor = c.paper, borderColor = c.rule,
                activeColor = c.primary, activeTextColor = c.ink,
            },
            ScrollView = {
                backgroundColor = c.paper, borderColor = c.rule,
            },
            Menu = {
                backgroundColor = c.paperLight, borderColor = c.gold,
                itemHoverBgColor = c.selected, itemHoverTextColor = c.ink,
            },
            Panel = { backgroundColor = false },
        },
    })
end

function Visual.Text(text, props)
    local result = copyProps(props)
    result.text = text or ""
    if result.fontFamily == nil and (result.serif == true or (result.fontSize or Tokens.body) >= 18) then
        result.fontFamily = "serif"
    end
    result.serif = nil
    result.fontSize = V7.Font(result.fontSize or Tokens.body)
    result.fontColor = result.fontColor or V7.Colors.ink
    return UI.Label(result)
end

function Visual.Button(text, onClick, props)
    return Skin.Button(text, onClick, props)
end

function Visual.PageHeader(title, subtitle, onBack, backId)
    local c = V7.Colors
    return UI.Row {
        width = "100%", height = 72, flexShrink = 0, gap = 8,
        paddingHorizontal = 12, paddingVertical = 8, alignItems = "center",
        borderRadius = 0, borderBottomWidth = 1, borderBottomColor = c.rule,
        children = {
            UI.Button {
                id = backId, width = 92, height = 56, flexShrink = 0,
                paddingHorizontal = 8, paddingVertical = 0,
                flexDirection = "row", alignItems = "center", justifyContent = "flex-start", gap = 8,
                variant = "secondary", borderWidth = 0, borderRadius = 5,
                backgroundColor = { 0, 0, 0, 0 },
                hoverBackgroundColor = { 53, 92, 73, 14 },
                pressedBackgroundColor = { 53, 92, 73, 28 },
                boxShadow = false, hoverBoxShadow = false, pressedBoxShadow = false,
                onClick = onBack,
                children = {
                    UI.Panel { width = 16, height = 24, justifyContent = "center", alignItems = "center", pointerEvents = "none", children = {
                        UI.Panel { width = 9, height = 9, rotate = 45, borderRadius = 0, borderLeftWidth = 1.5, borderBottomWidth = 1.5, borderLeftColor = c.primary, borderBottomColor = c.primary, pointerEvents = "none" },
                    } },
                    Visual.Text("首页", { fontSize = 16, fontFamily = "serif", fontColor = c.primary, whiteSpace = "nowrap" }),
                },
            },
            UI.Panel { flex = 1, minWidth = 0, gap = 2, alignItems = "center", pointerEvents = "none", children = {
                Visual.Text(title, { width = "100%", fontSize = 22, fontFamily = "serif", textAlign = "center", whiteSpace = "nowrap", lineHeight = 1.2 }),
                Visual.Text(subtitle, { width = "100%", fontSize = 12, fontColor = c.secondary, textAlign = "center", whiteSpace = "nowrap", lineHeight = 1.2 }),
            } },
            UI.Panel { width = 92, alignItems = "flex-end", pointerEvents = "none", children = {
                Visual.Decor("seal_square", { width = 24, height = 24, opacity = 0.8 }),
            } },
        },
    }
end

function Visual.Card(children, props)
    local result = copyProps(props)
    result.children = childrenOf(children)
    result.flexDirection = result.flexDirection or "column"
    result.gap = result.gap or 8
    result.padding = result.padding or 11
    result.backgroundColor = result.backgroundColor or V7.Colors.paperLight
    result.borderColor = result.borderColor or V7.Colors.rule
    result.borderWidth = result.borderWidth or Tokens.border
    result.borderRadius = result.borderRadius or Tokens.cardRadius or Tokens.panelRadius
    result.boxShadow = result.boxShadow or { { x = 0, y = 2, blur = 6, color = { 20, 43, 33, 14 } } }
    return UI.Panel(result)
end

function Visual.Paper(children, props)
    local result = copyProps(props)
    local decorationOpacity = result.decorationOpacity or 0.18
    local decorationChildren = {}
    if result.decorations ~= false then
        table.insert(decorationChildren, UI.Panel {
            position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
            backgroundImage = V7.Art.Decor("paper_edge"), backgroundFit = "fill",
            backgroundImageOpacity = decorationOpacity, pointerEvents = "none",
        })
    end
    local inner = UI.Panel {
        width = "100%", minWidth = 0, minHeight = 0,
        alignSelf = "stretch", flexGrow = 0, flexShrink = 1, flexBasis = "auto",
        flexDirection = "column", gap = result.gap or Tokens.sectionGap,
        padding = result.padding or Tokens.pageInset,
        children = childrenOf(children),
        borderWidth = Tokens.border, borderColor = V7.Colors.gold,
        borderRadius = result.innerRadius or 0,
        backgroundColor = V7.Colors.paperLight,
    }
    table.insert(decorationChildren, inner)
    if result.decorations ~= false then
        table.insert(decorationChildren, UI.Panel {
            position = "absolute", right = 0, top = 0, width = 48, height = 48,
            backgroundImage = V7.Art.Decor("corner"), backgroundFit = "contain",
            backgroundImageOpacity = decorationOpacity, pointerEvents = "none",
        })
    end
    result.children = decorationChildren
    result.padding = result.outerPadding or 4
    result.backgroundColor = V7.Colors.paper
    result.backgroundImage = result.backgroundImage or V7.Images.paperTexture
    result.backgroundImageOpacity = result.backgroundImageOpacity or 1
    result.backgroundFit = "cover"
    result.borderWidth = Tokens.border
    result.borderColor = V7.Colors.gold
    result.borderRadius = result.borderRadius or Tokens.panelRadius
    result.flexDirection = "column"
    return UI.Panel(result)
end

function Visual.Portrait(member, props)
    local result = copyProps(props)
    local size = result.size or 56
    local status = member.alive == false and "deceased" or (member.health and member.health < 35 and "sick" or nil)
    local path = Art.Portrait(member)
    local children = {
        Skin.Image(requireAsset(path, "人物 artId 或年龄阶段无效：" .. tostring(member.artId)), {
            position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
        }),
    }
    if status == "sick" then
        table.insert(children, UI.Panel {
            position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
            backgroundColor = { 106, 122, 108, 70 }, pointerEvents = "none",
        })
    elseif status == "deceased" then
        table.insert(children, UI.Panel {
            position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
            backgroundColor = { 41, 63, 55, 118 }, pointerEvents = "none",
        })
        table.insert(children, UI.Label {
            text = "故", position = "absolute", right = 4, bottom = 2, fontSize = V7.Font(12),
            fontFamily = "serif", fontColor = V7.Colors.paperLight, pointerEvents = "none",
        })
    end
    if result.selected then table.insert(children, Skin.Image(requireAsset(V7.Art.SelectedOverlay(), "selected 头像叠层未登记。"), {position = "absolute", left = 0, top = 0, width = "100%", height = "100%"})) end
    if result.focus and V7.Art.FocusOverlay then table.insert(children, Skin.Image(requireAsset(V7.Art.FocusOverlay(), "focus 头像叠层未登记。"), {position = "absolute", left = 0, top = 0, width = "100%", height = "100%"})) end
    if result.leader then table.insert(children, Skin.Image(requireAsset(V7.Art.LeaderOverlay(), "族长头像叠层未登记。"), {position = "absolute", left = 0, top = 0, width = "100%", height = "100%"})) end
    result.width = result.width or size
    result.height = result.height or size
    result.flexShrink = 0
    result.borderRadius = size / 2
    result.borderWidth = result.borderWidth or Tokens.border
    result.borderColor = result.borderColor or (result.leader and V7.Colors.primary or V7.Colors.gold)
    result.backgroundColor = result.backgroundColor or V7.Colors.paper
    result.overflow = "hidden"
    result.children = children
    return UI.Panel(result)
end

function Visual.Icon(name, size, tone)
    local actualSize = size or 24
    return Skin.Image(requireAsset(V7.Art.Icon(name, tone or "ink"), "图标未登记：" .. tostring(name)), {
        width = actualSize, height = actualSize,
    })
end

function Visual.Relic(id, size)
    local actualSize = size or 56
    return UI.Panel {
        width = actualSize, height = actualSize, padding = 5,
        backgroundColor = V7.Colors.paperLight, borderWidth = Tokens.border, borderColor = V7.Colors.gold,
        borderRadius = Tokens.buttonRadius,
        children = {Skin.Image(requireAsset(Art.Relic(id), "信物未登记：" .. tostring(id)), {width = "100%", height = "100%"})},
    }
end

function Visual.EventImage(event, relicId, props)
    if type(relicId) == "table" then
        props = relicId
        relicId = props.relicId
    end
    local result = copyProps(props)
    result.relicId = nil
    local image = Art.Event(event, relicId)
    result.backgroundImage = requireAsset(image, "事件插画未登记：" .. tostring(event and event.type))
    result.backgroundFit = result.backgroundFit or "cover"
    result.height = result.height or 132
    result.borderWidth = result.borderWidth or Tokens.border
    result.borderColor = result.borderColor or V7.Colors.gold
    return UI.Panel(result)
end

function Visual.House(homeId, state, props)
    local result = copyProps(props)
    result.backgroundImage = requireAsset(Art.House(homeId, state), "家宅状态未登记：" .. tostring(homeId) .. "/" .. tostring(state))
    result.backgroundFit = result.backgroundFit or "cover"
    result.borderWidth = result.borderWidth or Tokens.border
    result.borderColor = result.borderColor or V7.Colors.gold
    return UI.Panel(result)
end

function Visual.OpeningArt(name, props)
    local result = copyProps(props)
    result.backgroundImage = requireAsset(Art.Opening(name), "开局视觉资源未登记：" .. tostring(name))
    result.backgroundFit = result.backgroundFit or "cover"
    result.pointerEvents = result.pointerEvents or "none"
    return UI.Panel(result)
end

function Visual.Decor(name, props)
    local result = copyProps(props)
    result.backgroundFit = result.backgroundFit or "contain"
    result.pointerEvents = "none"
    return Skin.Image(requireAsset(V7.Art.Decor(name), "装饰未登记：" .. tostring(name)), result)
end

return Visual
