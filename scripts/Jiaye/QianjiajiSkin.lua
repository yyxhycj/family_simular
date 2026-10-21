local UI = require "urhox-libs/UI"

local Skin = {}
local ROOT = "Textures/Qianjiaji/"
Skin.Root = ROOT
Skin.FontFamily = "qianjiaji-song"
Skin.Colors = {
    paper = {246, 239, 221, 255}, paperLight = {251, 246, 232, 255},
    ink = {23, 59, 51, 255}, muted = {117, 109, 95, 255},
    rule = {200, 185, 154, 255}, red = {172, 75, 54, 255},
    selected = {227, 229, 213, 255}, disabled = {153, 148, 132, 255},
}
Skin.Art = {
    world = ROOT .. "World/mountain_river.png",
    courtyard = ROOT .. "Buildings/rented_courtyard.png",
    book = ROOT .. "Heirlooms/genealogy_book.png",
    letter = ROOT .. "Heirlooms/unsent_letter.png",
}

local function copy(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

function Skin.Font(px) return px * 72 / 96 end

function Skin.Text(value, props)
    local p = copy(props)
    p.text = tostring(value or "")
    p.fontFamily = p.fontFamily or Skin.FontFamily
    p.fontSize = Skin.Font(p.fontSize or 17)
    p.fontColor = p.fontColor or Skin.Colors.ink
    p.lineHeight = p.lineHeight or 1.45
    p.flexShrink = p.flexShrink or 0
    p.pointerEvents = p.pointerEvents or "none"
    return UI.Label(p)
end

function Skin.Image(path, props)
    assert(type(path) == "string" and path ~= "", "插画路径为空。")
    local p = copy(props)
    p.backgroundImage = path
    p.backgroundFit = p.backgroundFit or "contain"
    p.backgroundColor = p.backgroundColor or false
    p.pointerEvents = p.pointerEvents or "none"
    p.flexShrink = p.flexShrink or 0
    p.borderRadius = p.borderRadius or 0
    local panel = UI.Panel(p)
    if p.backgroundFit == "contain" then
        local source = assert(cache:GetResource("Image", path), "插画无法加载：" .. path)
        local ratio = source.width / source.height
        function panel:Render(nvg)
            local rect = self:GetAbsoluteLayout()
            local width = math.min(rect.w, rect.h * ratio)
            local height = width / ratio
            self:RenderBackgroundImage(nvg, path, {x = rect.x + (rect.w - width) / 2, y = rect.y + (rect.h - height) / 2, w = width, h = height}, "fill")
        end
    end
    return panel
end

function Skin.Icon(name, size, tone)
    return Skin.Image(ROOT .. "Icons/" .. (tone or "ink") .. "/" .. name .. ".png", {width = size or 24, height = size or 24})
end

function Skin.NineSlice(file, border, props)
    local p = copy(props)
    p.backgroundImage = ROOT .. "UI/" .. file
    p.backgroundFit = "sliced"
    p.backgroundSlice = {border, border, border, border}
    p.borderWidth, p.borderRadius = 0, 0
    return UI.Panel(p)
end

function Skin.Line(props)
    local p = copy(props)
    p.height = p.height or 1
    p.backgroundColor = p.backgroundColor or Skin.Colors.rule
    p.flexShrink, p.pointerEvents, p.borderRadius = 0, "none", 0
    return UI.Panel(p)
end

function Skin.Button(label, onClick, props)
    local p = copy(props)
    local role = p.role or p.variant or "primary"
    assert(role == "primary" or role == "secondary" or role == "danger", "未知按钮样式。")
    local surface = role == "primary" and "primary" or "secondary"
    local prefix = ROOT .. "UI/button_" .. surface .. "_"
    p.role, p.variant, p.text, p.onClick = nil, surface, label or "", onClick
    p.disabled = p.disabled or p.busy or false
    p.backgroundImage = prefix .. (p.disabled and "disabled" or (p.selected and "pressed" or "normal")) .. ".png"
    p.pressedBackgroundImage = prefix .. "pressed.png"
    p.hoverBackgroundImage = prefix .. "hover.png"
    p.disabledBackgroundImage = prefix .. "disabled.png"
    p.backgroundFit, p.backgroundSlice = "sliced", {12, 12, 12, 12}
    p.backgroundColor, p.hoverBackgroundColor, p.pressedBackgroundColor = {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}
    p.borderWidth, p.borderRadius = 0, 0
    p.boxShadow, p.hoverBoxShadow, p.pressedBoxShadow = false, false, false
    p.fontFamily, p.fontSize = Skin.FontFamily, Skin.Font(p.fontSize or 17)
    p.textColor = p.textColor or (role == "danger" and Skin.Colors.red or (role == "primary" and Skin.Colors.paperLight or Skin.Colors.ink))
    p.disabledTextColor = Skin.Colors.disabled
    p.height, p.minHeight, p.flexShrink = p.height or 48, 44, 0
    return UI.Button(p)
end

function Skin.TextAction(label, onClick, props)
    local p = copy(props)
    p.minHeight, p.flexShrink = 48, 0
    p.justifyContent = p.justifyContent or "center"
    p.alignItems = p.alignItems or "center"
    if p.disabled then p.onClick = nil else p.onClick = onClick end
    p.pointerEvents, p.backgroundColor = "box-only", false
    p.children = {Skin.Text(label, {fontSize = p.fontSize or 17, fontColor = p.disabled and Skin.Colors.disabled or (p.textColor or Skin.Colors.ink)})}
    return UI.Panel(p)
end

function Skin.IconAction(name, onClick, props)
    local p = copy(props)
    p.width, p.height = p.width or 44, p.height or 44
    p.minWidth, p.minHeight = 44, 44
    if p.disabled then p.onClick = nil else p.onClick = onClick end
    p.pointerEvents, p.backgroundColor = "box-only", false
    p.alignItems, p.justifyContent, p.flexShrink = "center", "center", 0
    p.children = {Skin.Icon(name, 22, p.disabled and "muted" or "ink")}
    return UI.Panel(p)
end

function Skin.Section(title, children, note)
    local heading = {Skin.Text(title, {fontSize = 21})}
    if note then heading[#heading + 1] = Skin.Text(note, {fontSize = 14, fontColor = Skin.Colors.muted, textAlign = "right"}) end
    local content = {
        UI.Row {alignItems = "center", justifyContent = "space-between", gap = 12, children = heading},
        Skin.Line(),
    }
    for _, child in ipairs(children or {}) do content[#content + 1] = child end
    return UI.Panel {width = "100%", gap = 12, flexShrink = 0, children = content}
end

function Skin.OptionRow(spec)
    local action = spec.onClick
    if spec.disabled then action = nil end
    ---@type Widget[]
    local description = {Skin.Text(spec.label, {fontSize = 18, fontColor = spec.disabled and Skin.Colors.disabled or Skin.Colors.ink})}
    if spec.description and spec.description ~= "" then description[#description + 1] = Skin.Text(spec.description, {width = "100%", whiteSpace = "normal", fontSize = 14, fontColor = Skin.Colors.muted}) end
    ---@type Widget[]
    local children = {
        Skin.Icon(spec.selected and "radio_on" or "radio_off", 22, spec.disabled and "muted" or "ink"),
        UI.Panel {flex = 1, minWidth = 0, gap = 4, children = description},
    }
    if spec.costText then children[#children + 1] = Skin.Text(spec.costText, {fontSize = 16, textAlign = "right"}) end
    return UI.Panel {
        id = spec.id, width = "100%", minHeight = 64, paddingVertical = 10, paddingHorizontal = 8,
        flexDirection = "row", gap = 12, alignItems = "center", flexShrink = 0,
        onClick = action, pointerEvents = "box-only", backgroundColor = false,
        backgroundImage = spec.selected and (ROOT .. "UI/row_selected.png") or nil,
        backgroundFit = "sliced", backgroundSlice = {12, 12, 12, 12}, borderRadius = 0,
        children = children,
    }
end

function Skin.Stepper(spec)
    return UI.Row {gap = 4, alignItems = "center", flexShrink = 0, children = {
        Skin.IconAction("minus", spec.onDecrease, {id = spec.id and spec.id .. "-decrease", disabled = spec.canDecrease == false}),
        Skin.Text(spec.valueText or spec.value, {width = spec.valueWidth or 64, textAlign = "center", fontSize = 19}),
        Skin.IconAction("plus", spec.onIncrease, {id = spec.id and spec.id .. "-increase", disabled = spec.canIncrease == false}),
    }}
end

function Skin.LedgerRow(spec)
    local columns = {}
    for _, cell in ipairs(spec.values or {}) do
        columns[#columns + 1] = UI.Row {
            width = cell.width or 90, flexShrink = 0, gap = 4,
            justifyContent = "flex-end", alignItems = "baseline", children = {
                Skin.Text(cell.text, {fontSize = spec.total and 20 or 17, fontWeight = spec.total and "bold" or "normal", textAlign = "right", fontColor = cell.color or Skin.Colors.ink}),
                Skin.Text(cell.unit or "", {width = cell.unitWidth or 20, fontSize = 13, fontColor = Skin.Colors.muted}),
            },
        }
    end
    local label = {Skin.Text(spec.label, {width = "100%", whiteSpace = "normal", fontSize = 17, fontWeight = spec.total and "bold" or "normal"})}
    if spec.note and spec.note ~= "" then label[#label + 1] = Skin.Text(spec.note, {width = "100%", whiteSpace = "normal", fontSize = 13, fontColor = Skin.Colors.muted}) end
    local children = {UI.Panel {flex = 1, minWidth = 0, gap = 3, children = label}}
    for _, column in ipairs(columns) do children[#children + 1] = column end
    return UI.Panel {
        id = spec.id, width = "100%", flexShrink = 0, paddingVertical = 12, borderRadius = 0,
        onClick = spec.onClick, pointerEvents = spec.onClick and "box-only" or "none",
        borderTopWidth = spec.total and 1 or 0, borderTopColor = Skin.Colors.ink,
        borderBottomWidth = spec.total and 0 or 1, borderBottomColor = Skin.Colors.rule,
        children = {UI.Row {alignItems = "center", gap = 8, children = children}},
    }
end

function Skin.MemberRow(spec)
    local heading = {Skin.Text(spec.name, {fontSize = 21})}
    if spec.isLeader then heading[#heading + 1] = Skin.Text("族长", {fontSize = 13, fontColor = Skin.Colors.red}) end
    return UI.Panel {
        id = spec.id, width = "100%", minHeight = 112, flexShrink = 0, paddingVertical = 6, borderRadius = 0,
        borderBottomWidth = 1, borderBottomColor = Skin.Colors.rule,
        onClick = spec.onClick, pointerEvents = spec.onClick and "box-only" or "auto",
        children = {UI.Row {alignItems = "center", gap = 14, children = {
            Skin.Image(spec.portrait, {width = 70, height = 102}),
            UI.Panel {flex = 1, minWidth = 0, gap = 5, children = {
                UI.Row {gap = 12, alignItems = "center", children = heading},
                Skin.Text(spec.relationText, {fontSize = 15}),
                Skin.Text(spec.detailText, {fontSize = 14, fontColor = Skin.Colors.muted}),
            }},
            Skin.Icon("chevron_right", 18),
        }}},
    }
end

function Skin.Tabs(tabs, activeId, onSelect)
    local children = {}
    for _, tab in ipairs(tabs or {}) do
        children[#children + 1] = UI.Panel {
            id = "opening-tab-" .. tab.id, flex = 1, minHeight = 44, alignItems = "center", justifyContent = "center",
            onClick = function() onSelect(tab.id) end, pointerEvents = "box-only", backgroundColor = false,
            backgroundImage = tab.id == activeId and (ROOT .. "UI/tab_active.png") or nil,
            backgroundFit = "sliced", backgroundSlice = {8, 8, 8, 8}, borderRadius = 0,
            children = {Skin.Text(tab.label, {fontSize = 17, fontColor = tab.id == activeId and Skin.Colors.ink or Skin.Colors.muted})},
        }
    end
    return UI.Row {width = "100%", flexShrink = 0, children = children}
end

function Skin.Header(spec)
    local left = UI.Panel {width = 76, height = 44, pointerEvents = "none"}
    if spec.onBack then
        left = UI.Panel {id = spec.backId, width = 76, minHeight = 44, pointerEvents = "box-only", onClick = spec.onBack, justifyContent = "center", children = {
            UI.Row {alignItems = "center", gap = 6, children = {Skin.Icon("back", 20), Skin.Text(spec.backText or "返回", {fontSize = 16})}},
        }}
    end
    local right = spec.onEdit and Skin.IconAction("edit", spec.onEdit, {id = spec.editId}) or UI.Panel {width = 44, height = 44, pointerEvents = "none"}
    return UI.Panel {width = "100%", flexShrink = 0, children = {
        UI.Row {width = "100%", minHeight = 68, paddingHorizontal = 20, paddingVertical = 8, alignItems = "center", gap = 8, children = {
            left,
            UI.Panel {flex = 1, minWidth = 0, gap = 2, children = {
                Skin.Text(spec.title, {width = "100%", fontSize = 23, textAlign = "center"}),
                Skin.Text(spec.subtitle, {width = "100%", fontSize = 12, fontColor = Skin.Colors.muted, textAlign = "center"}),
            }},
            UI.Panel {width = 76, alignItems = "flex-end", children = {right}},
        }},
        Skin.Line({marginHorizontal = 24}),
    }}
end

function Skin.Page(spec)
    local content = {}
    if spec.feedback and spec.feedback ~= "" then content[#content + 1] = Skin.Text(spec.feedback, {fontSize = 14, fontColor = Skin.Colors.red}) end
    for _, child in ipairs(spec.children or {}) do content[#content + 1] = child end
    local children = {
        Skin.Header(spec),
        UI.ScrollView {
            id = spec.scrollId or "opening-scroll", width = "100%", flexGrow = 1, flexBasis = 0, minHeight = 0,
            scrollX = false, showScrollbar = false, backgroundColor = false,
            children = {UI.Panel {width = "100%", padding = spec.padding or 24, gap = spec.gap or 22, flexShrink = 0, children = content}},
        },
    }
    local footer = spec.footer or {}
    if spec.editing then
        if spec.footerNote then footer[#footer + 1] = Skin.Text(spec.footerNote, {fontSize = 13, fontColor = Skin.Colors.muted, textAlign = "right"}) end
        footer[#footer + 1] = UI.Row {gap = 20, alignItems = "center", children = {
            Skin.TextAction("取消", spec.onCancel, {id = "opening-cancel", width = 72}),
            UI.Panel {flex = 1},
            Skin.Button(spec.saveLabel or "保存", spec.onSave, {id = "opening-save", width = 120, disabled = spec.saveDisabled == true}),
        }}
    end
    if #footer > 0 then
        children[#children + 1] = UI.Panel {id = "opening-footer", flexShrink = 0, paddingHorizontal = 24, paddingVertical = 12, gap = 8, borderRadius = 0, borderTopWidth = 1, borderTopColor = Skin.Colors.rule, backgroundColor = Skin.Colors.paper, children = footer}
    end
    return Skin.NineSlice("paper_sheet.png", 24, {id = spec.id, width = "100%", height = "100%", overflow = "hidden", backgroundColor = Skin.Colors.paper, flexDirection = "column", children = children})
end

return Skin
