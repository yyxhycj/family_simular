local UI = require "urhox-libs/UI"
local V7 = require "Jiaye.V7"
local Skin = require "Jiaye.QianjiajiSkin"

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
        onBack = props.onBack,
    }

    function sheet:AddContent(content)
        self.content = content
        if self.body then
            self.body:ClearChildren()
            self.body:AddChild(content)
        end
    end

    function sheet:SetFooter(footer)
        self.footer = footer
    end

    function sheet:SetBack(onBack)
        self.onBack = onBack
    end

    function sheet:Destroy()
        if self.destroyed then return end
        self.destroyed = true
        local drawer = self.drawer
        self.drawer = nil
        if drawer then
            local children = drawer:GetHitTestChildren()
            drawer:Destroy()
            for _, child in ipairs(children) do child:Destroy() end
        end
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
        drawerProps.header = nil
        drawerProps.showCloseButton = false
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
        drawerProps.contentPadding = 0
        self.body = UI.Panel {width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0, minHeight = 0,
            padding = self.props.contentPadding or {12, 14}, overflow = "hidden",
            children = self.content and {self.content} or {}}
        local children = {
            Skin.Header {title = self.title, onBack = function()
                if self.onBack then self.onBack() else self:Close() end
            end, backId = (self.props.id or "sheet") .. "-back"},
            self.body,
        }
        if self.footer then
            table.insert(children, UI.Panel {width = "100%", flexShrink = 0,
                padding = self.props.footerPadding or {8, 14}, children = {self.footer}})
        end
        local content = UI.SafeAreaView {width = "100%", height = "100%", edges = {"bottom", "left", "right"},
            minHeight = 0, overflow = "hidden", children = children}
        drawerProps.content = content
        drawerProps.footer = nil
        drawerProps.onClose = function()
            if self.props.onClose then self.props.onClose(self) end
            if not self.destroyed then self:Destroy() end
        end

        local drawer = UI.Drawer(drawerProps)
        local updateDrawer = drawer.Update
        -- 自绘内容逐帧更新滚动范围、惯性和控件状态。
        local function updateContent(widget, dt)
            if widget.Update then widget:Update(dt) end
            for _, child in ipairs(widget.children or {}) do updateContent(child, dt) end
        end
        function drawer:Update(dt)
            self.size_ = sheetHeight(self.props.sheet or "detail")
            updateDrawer(self, dt)
            updateContent(content, dt)
        end
        local closeOnOverlay = self.props.closeOnOverlay ~= false
        function drawer:GetHitTestChildren()
            local children = {}
            if content and type(content) ~= "function" then table.insert(children, content) end
            return children
        end
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
