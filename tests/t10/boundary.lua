-- 仅替换 UrhoX 的 File/cjson 边界；State 与 Simulation 保持生产实现。
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
