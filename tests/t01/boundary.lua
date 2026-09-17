-- Only engine boundaries are replaced. No game rules or PRNG are substituted.
UI, notices = {}, {}
local function widget(kind, props)
    props = props or {}; props.kind = kind; props.children = props.children or {}
    props.SetText = function(self, text) self.text = text end
    props.SetValue = function(self, value) self.value = value end
    props.GetValue = function(self) return self.value end
    props.SetDisabled = function(self, value) self.disabled = value end
    props.SetOptions = function(self, value) self.options = value end
    props.SetScroll = function(self, x, y) self.scrollX, self.scrollY = x, y end
    props.GetScroll = function(self) return self.scrollX or 0, self.scrollY or 0 end
    props.AddChild = function(self, child) table.insert(self.children, child) end
    props.AddContent = props.AddChild
    props.GetChildAt = function(self, index) return self.children[index] end
    props.SetFooter = function(self, footer) self.footer = footer; self:AddChild(footer) end
    props.Open = function(self) UI.modal = self end
    props.Close = function(self) if self.onClose then self.onClose(self) end end
    props.Destroy = function(self) self.destroyed = true end
    return props
end
for _, kind in ipairs({ "Panel", "Row", "SimpleGrid", "Dropdown", "Label", "Button", "TextField", "Stepper", "Toggle", "ScrollView", "Divider", "SafeAreaView", "Box", "Modal" }) do
    UI[kind] = function(props) return widget(kind, props) end
end
UI.Box = function(width, height) return widget("Box", { width = width, height = height }) end
UI.SetRoot = function(root) UI.root = root end
UI.Toast = {
    GetGlobal = function() return { DismissAll = function() end } end,
    Show = function(message, props) table.insert(notices, { message = message, variant = props.variant }) end,
}
package.loaded["urhox-libs/UI"] = UI
FILE_READ, FILE_WRITE = 1, 2
File = function(path, mode)
    local handle = disk_open(path, mode)
    return {
        IsOpen = function() return handle ~= nil end,
        WriteString = function(_, raw) return disk_write(handle, raw) end,
        ReadString = function() return disk_read(handle) end,
        Close = function() disk_close(handle) end,
    }
end
fileSystem = { FileExists = function(_, path) return disk_exists(path) end }
