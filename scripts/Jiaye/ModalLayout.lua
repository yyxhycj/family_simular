local UI = require "urhox-libs/UI"
local V7 = require "Jiaye.V7"

local ModalLayout = {}

local C = V7.Colors

local heightRatios = {
    menu = 0.53,
    confirm = 0.50,
    detail = 0.76,
    form = 0.84,
    full = 0.91,
}

local function sheetHeight(kind)
    local ratio = heightRatios[kind or "detail"] or heightRatios.detail
    return math.floor(UI.GetHeight() * ratio)
end

function ModalLayout.New(title, props)
    props = props or {}
    local sheet = {
        title = title,
        props = props,
        content = nil,
        footer = nil,
        drawer = nil,
        destroyed = false,
    }

    function sheet:AddContent(content)
        self.content = content
    end

    function sheet:SetFooter(footer)
        self.footer = footer
    end

    function sheet:Destroy()
        if self.destroyed then return end
        self.destroyed = true
        local drawer = self.drawer
        self.drawer = nil
        if drawer then drawer:Destroy() end
    end

    function sheet:Close()
        if self.drawer then self.drawer:Close() end
    end

    function sheet:Open()
        if self.destroyed or self.drawer then return end
        local drawerProps = {}
        for key, value in pairs(self.props) do drawerProps[key] = value end
        drawerProps.position = "bottom"
        drawerProps.size = sheetHeight(self.props.sheet or "detail")
        drawerProps.header = self.title
        drawerProps.headerHeight = self.props.headerHeight or 52
        drawerProps.showCloseButton = true
        drawerProps.showOverlay = true
        drawerProps.overlayOpacity = self.props.overlayOpacity or 0.58
        drawerProps.animationDuration = self.props.animationDuration or 0.22
        drawerProps.backgroundColor = self.props.backgroundColor or C.paperLight
        drawerProps.backgroundImage = self.props.backgroundImage or V7.Images.paperTexture
        drawerProps.backgroundImageOpacity = self.props.backgroundImageOpacity or 1
        drawerProps.backgroundFit = self.props.backgroundFit or "cover"
        drawerProps.borderWidth = self.props.borderWidth or 1
        drawerProps.borderColor = self.props.borderColor or C.gold
        drawerProps.borderRadius = self.props.borderRadius or V7.Tokens.sheetTopRadius
        drawerProps.contentPadding = self.props.contentPadding or { 12, 14 }
        drawerProps.footerPadding = self.props.footerPadding or { 8, 14 }
        drawerProps.content = self.content
        drawerProps.footer = self.footer
        drawerProps.onClose = function()
            if self.props.onClose then self.props.onClose(self) end
            if not self.destroyed then self:Destroy() end
        end

        local drawer = UI.Drawer(drawerProps)
        local closeOnOverlay = self.props.closeOnOverlay ~= false
        function drawer:OnClick(event)
            if not event then return end
            local px, py = event.x, event.y
            if self.showCloseButton_ and self:PointInBounds(px, py, self.closeButtonBounds_) then
                self:Close()
                return true
            end
            if self.variant_ == "temporary" and closeOnOverlay and not self:PointInBounds(px, py, self.drawerBounds_) then
                self:Close()
                return true
            end
            return false
        end
        self.drawer = drawer
        local root = assert(UI.GetRoot(), "移动页面缺少游戏根节点。")
        root:AddChild(drawer)
        drawer:Open()
    end

    return sheet
end

function ModalLayout.Scroll(child, props)
    props = props or {}
    props.width = props.width or "100%"
    props.height = nil
    props.flexGrow = 1
    props.flexShrink = 1
    props.flexBasis = 0
    props.scrollX = false
    props.showScrollbar = false
    props.children = props.children or { child }
    return UI.ScrollView(props)
end

function ModalLayout.NeedsScroll(detail, visual)
    return visual ~= nil or #tostring(detail or "") > 300
end

return ModalLayout
