local UI = require "urhox-libs/UI"

local ModalLayout = {}

function ModalLayout.New(title, props)
    props = props or {}
    props.title = title
    props.size = "sm"
    props.headerHeight = props.headerHeight or 50
    props.contentPadding = props.contentPadding or { 8, 12, 8, 12 }
    props.footerPadding = props.footerPadding or { 8, 12, 8, 12 }
    return UI.Modal(props)
end

function ModalLayout.Scroll(child, props)
    props = props or {}
    props.width = props.width or "100%"
    props.height = props.height or 270
    props.children = props.children or { child }
    return UI.ScrollView(props)
end

function ModalLayout.NeedsScroll(detail, visual)
    return visual ~= nil or #tostring(detail or "") > 300
end

return ModalLayout
