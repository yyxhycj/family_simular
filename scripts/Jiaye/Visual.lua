local UI = require "urhox-libs/UI"
local Theme = require "urhox-libs/UI/Core/Theme"
local V7 = require "Jiaye.V7"
local Art = require "Jiaye.Art"

local Visual = {}
local currentArtVersion = nil

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

local function buttonState(props)
    if props.busy then return "busy" end
    if props.disabled then return "disabled" end
    if props.confirm then return "confirm" end
    if props.selected then return "selected" end
    if props.focus then return "focus" end
    return props.state or "default"
end

local function buttonImage(role, state)
    return requireAsset(V7.ButtonImage(role, state), "V7 按钮角色或状态未登记：" .. tostring(role) .. "/" .. tostring(state))
end

function Visual.SetArtVersion(version)
    currentArtVersion = version == nil and nil or Art.NormalizeVersion(version)
    return currentArtVersion
end

function Visual.GetArtVersion()
    return currentArtVersion
end

function Visual.Theme()
    local c = V7.Colors
    return Theme.ExtendTheme(Theme.defaultTheme, {
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/NotoSansSC-Regular.ttf",
                bold = "Fonts/NotoSansSC-Bold.ttf",
            }},
            { family = "serif", weights = {
                normal = "Fonts/SourceHanSerifCN-Regular.otf",
                bold = "Fonts/SourceHanSerifCN-SemiBold.otf",
            }},
        },
        typography = {
            fontFamily = "sans",
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
    local result = copyProps(props)
    local role = rawget(result, "role") or rawget(result, "variant") or "primary"
    if role ~= "primary" and role ~= "secondary" and role ~= "danger" then
        error("V7 按钮角色无效：" .. tostring(role), 2)
    end
    local state = buttonState(result)
    assert(state == "default" or state == "pressed" or state == "disabled" or state == "focus"
        or state == "selected" or state == "confirm" or state == "busy", "V7 按钮状态无效：" .. tostring(state))
    result.text = text or ""
    result.onClick = onClick
    result.variant = role
    result.height = result.height or Tokens.primaryHeight
    result.minHeight = result.minHeight or Tokens.touchMin
    result.fontSize = V7.Font(result.fontSize or Tokens.control)
    result.borderRadius = result.borderRadius or Tokens.buttonRadius
    result.backgroundImage = result.backgroundImage or buttonImage(role, state)
    result.pressedBackgroundImage = result.pressedBackgroundImage or buttonImage(role, "pressed")
    result.hoverBackgroundImage = result.hoverBackgroundImage or buttonImage(role, "focus")
    result.disabledBackgroundImage = result.disabledBackgroundImage or buttonImage(role, "disabled")
    result.backgroundFit = "fill"
    result.backgroundSlice = result.backgroundSlice or Tokens.buttonSlice or { 36, 36, 36, 36 }
    result.disabled = result.disabled or state == "disabled" or state == "busy"
    result.textColor = result.textColor or (role == "secondary" and V7.Colors.ink or V7.Colors.paperLight)
    result.disabledTextColor = result.disabledTextColor or V7.Colors.disabledInk
    result.borderWidth = result.borderWidth or 0
    return UI.Button(result)
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
    local path = Art.Portrait(member, result.detail and "detail" or "normal", status)
    local children = {
        UI.Panel {
            position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
            backgroundImage = requireAsset(path, "人物 artId 或年龄阶段无效：" .. tostring(member.artId)),
            backgroundFit = "contain", pointerEvents = "none",
        },
    }
    if result.selected then table.insert(children, UI.Panel { position = "absolute", left = 0, top = 0, width = "100%", height = "100%", backgroundImage = requireAsset(V7.Art.SelectedOverlay(), "selected 头像叠层未登记。"), backgroundFit = "contain", pointerEvents = "none" }) end
    if result.focus and V7.Art.FocusOverlay then table.insert(children, UI.Panel { position = "absolute", left = 0, top = 0, width = "100%", height = "100%", backgroundImage = requireAsset(V7.Art.FocusOverlay(), "focus 头像叠层未登记。"), backgroundFit = "contain", pointerEvents = "none" }) end
    if result.leader then table.insert(children, UI.Panel { position = "absolute", left = 0, top = 0, width = "100%", height = "100%", backgroundImage = requireAsset(V7.Art.LeaderOverlay(), "族长头像叠层未登记。"), backgroundFit = "contain", pointerEvents = "none" }) end
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
    return UI.Panel {
        width = actualSize, height = actualSize,
        backgroundImage = requireAsset(V7.Art.Icon(name, tone or "ink"), "图标未登记：" .. tostring(name)),
        backgroundFit = "contain", pointerEvents = "none",
    }
end

function Visual.Relic(id, size)
    local actualSize = size or 56
    return UI.Panel {
        width = actualSize, height = actualSize, padding = 5,
        backgroundColor = V7.Colors.paperLight, backgroundImage = requireAsset(Art.Relic(id, currentArtVersion), "信物未登记：" .. tostring(id)),
        backgroundFit = "contain", borderWidth = Tokens.border, borderColor = V7.Colors.gold,
        borderRadius = Tokens.buttonRadius,
    }
end

function Visual.EventImage(event, relicId, props)
    if type(relicId) == "table" then
        props = relicId
        relicId = props.relicId
    end
    local result = copyProps(props)
    result.relicId = nil
    local image = Art.Event(event, relicId, currentArtVersion)
    result.backgroundImage = requireAsset(image, "事件插画未登记：" .. tostring(event and event.type))
    result.backgroundFit = result.backgroundFit or "cover"
    result.height = result.height or 132
    result.borderWidth = result.borderWidth or Tokens.border
    result.borderColor = result.borderColor or V7.Colors.gold
    return UI.Panel(result)
end

function Visual.House(homeId, state, props)
    local result = copyProps(props)
    result.backgroundImage = requireAsset(Art.House(homeId, state, currentArtVersion), "家宅状态未登记：" .. tostring(homeId) .. "/" .. tostring(state))
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
    result.backgroundImage = requireAsset(V7.Art.Decor(name), "装饰未登记：" .. tostring(name))
    result.backgroundFit = result.backgroundFit or "contain"
    result.pointerEvents = "none"
    return UI.Panel(result)
end

return Visual
