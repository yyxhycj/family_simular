local State = require "Jiaye.State"
local cjson = require "cjson"
local Achievements = require "Jiaye.Achievements"

local CloudSave = {}
CloudSave.__index = CloudSave
CloudSave.KEY = "jiaye_save_v1"

local function ownerId()
    if not clientCloud or type(clientCloud.userId) ~= "number" or clientCloud.userId <= 0 then return "" end
    return tostring(math.floor(clientCloud.userId))
end

local function revision(envelope)
    return envelope and envelope.revision or ""
end

local function descendsFrom(envelope, base)
    if envelope.parentRevision == base then return true end
    for _, ancestor in ipairs(envelope.ancestors or {}) do if ancestor == base then return true end end
    return false
end

local function validSync(sync, owner)
    return type(sync) == "table" and sync.ownerId == owner and type(sync.baseRevision) == "string"
        and (sync.pendingRevision == nil or (type(sync.pendingRevision) == "string" and sync.pendingRevision ~= ""))
        and (sync.previousRevision == nil or (type(sync.previousRevision) == "string" and sync.previousRevision ~= ""))
        and type(sync.savedAt) == "number" and sync.savedAt == sync.savedAt and sync.savedAt >= 0 and sync.savedAt < math.huge
end

local function decode(value, owner)
    if value == nil or value == cjson.null then return nil end
    if type(value) ~= "table" or value.format ~= 1 or value.ownerId ~= owner
        or type(value.revision) ~= "string" or value.revision == "" or #value.revision > 200
        or type(value.parentRevision) ~= "string" or type(value.updatedAt) ~= "number"
        or value.updatedAt ~= value.updatedAt or value.updatedAt < 0 or value.updatedAt >= math.huge or type(value.data) ~= "string" then
        return nil, "云端存档信息无效，已停止同步，请重试。"
    end
    local payload = State.PreflightImport(value.data)
    if not payload then return nil, "云端家谱未通过版本与内容校验，已保留本机进度。" end
    payload.cloudSync = nil
    if value.ancestors ~= nil then
        if type(value.ancestors) ~= "table" or #value.ancestors > 64 then return nil, "云端存档历史版本无效，已停止同步。" end
        for _, ancestor in ipairs(value.ancestors) do
            if type(ancestor) ~= "string" or ancestor == "" or #ancestor > 200 then return nil, "云端存档历史版本无效，已停止同步。" end
        end
    end
    value.payload = payload
    return value
end

function CloudSave.New(legacy, onLoad, onChange, key)
    local self = setmetatable({}, CloudSave)
    self:Init(legacy, onLoad, onChange, key)
    return self
end

function CloudSave:Init(legacy, onLoad, onChange, key)
    assert(ownerId() ~= "", "启动云存档需要引擎完成 TapTap 登录。")
    assert(type(clientCloud.mapName) == "string" and clientCloud.mapName:find("%S"),
        "当前运行环境缺少游戏项目标识，无法使用云存档。")
    self.project = clientCloud.mapName
    self.key = key or CloudSave.KEY
    self.storageNamespace = self.key
    self.legacy = legacy
    self.onLoad = onLoad
    self.onChange = onChange
    self.owner = ""
    self.session = tostring(os.time()) .. "-" .. tostring(math.random(1, 2147483647))
    self.serial = 0
    self.clock = 0
    self.nextAttempt = 0
    self.retryUntil = 0
    self.nextUploadAt = 0
    self.deadline = 0
    self.attempts = 0
    self.requestId = 0
    self.busy = false
    self.ready = false
    self.blocked = true
    self.state = "reading"
    self.message = "正在读取云端家谱…"
    self.localPayload = nil
    self.remote = nil
    self.sending = nil
    self.conflict = false
    self.stopped = false
    self.forceRead = false
    self.chooseCloud = false
end

function CloudSave:Status(state, message)
    self.state, self.message = state, message
    self.onChange()
end

function CloudSave:Fail(message)
    self.busy = false
    self.requestId = self.requestId + 1
    self.attempts = self.attempts + 1
    self.nextAttempt = self.clock + math.min(30, 2 ^ math.min(self.attempts, 5))
    self.retryUntil = self.nextAttempt
    self:Status("error", message .. " 将自动重试，请保持游戏开启。")
end

function CloudSave:Request(send, done)
    assert(ownerId() == self.owner and clientCloud.mapName == self.project,
        "云存档账号或游戏项目已变化，请重新打开游戏。")
    self.requestId = self.requestId + 1
    local id, owner, settled = self.requestId, self.owner, false
    self.busy = true
    self.deadline = self.clock + 20
    self.onChange()
    local function current()
        return not settled and not self.stopped and self.requestId == id
            and ownerId() == owner and clientCloud.mapName == self.project
    end
    send({
        ok = function(...)
            if not current() then return end
            settled = true
            self.busy = false
            done(...)
        end,
        error = function(code, reason)
            if current() then
                settled = true
                self:Fail("云端存档读取或保存失败（" .. tostring(code) .. "）：" .. tostring(reason))
            end
        end,
        timeout = function()
            if current() then settled = true; self:Fail("云端同步超时，当前进度尚未完成同步。") end
        end,
    })
end

function CloudSave:NextMetadata()
    assert(self.owner ~= "" and not self.blocked, "云端家谱尚未就绪。")
    self.serial = self.serial + 1
    local sync = self.localPayload and self.localPayload.cloudSync
    return {
        ownerId = self.owner,
        baseRevision = sync and sync.baseRevision or "",
        pendingRevision = self.session .. "-" .. tostring(self.serial),
        previousRevision = self.sending and self.sending.revision or (sync and sync.previousRevision),
        savedAt = os.time(),
    }
end

function CloudSave:Queue(payload)
    assert(validSync(payload.cloudSync, self.owner), "待同步家谱缺少账号信息。")
    self.localPayload = payload
    self.nextAttempt = math.max(self.clock, self.retryUntil)
    self:Status("pending", "正在自动保存到云端…")
end

function CloudSave:Cache(payload, sync)
    local ok, message, saved = State.Save(payload.profile, payload.draft, payload.run, {
        cloudSync = sync, allowRecoveryOverwrite = true,
    })
    if not ok then
        self.blocked = true
        self:Fail("本机存档写入失败：" .. message)
        return false
    end
    self.localPayload = saved
    self.localInvalid = false
    return true
end

function CloudSave:Adopt(remote)
    local previous = self.localPayload and self.localPayload.cloudSync
    local alreadyLoaded = self.ready and previous
        and (previous.pendingRevision == remote.revision or (not previous.pendingRevision and previous.baseRevision == remote.revision))
    local payload = State.Copy(remote.payload)
    local merged = Achievements.Merge(payload.profile, self.localPayload and self.localPayload.profile)
    local _, updated = Achievements.Update(payload.profile, payload.run)
    local sync = { ownerId = self.owner, baseRevision = remote.revision, savedAt = remote.updatedAt }
    if merged or updated then
        self.serial = self.serial + 1
        sync.pendingRevision = self.session .. "-" .. tostring(self.serial)
        sync.savedAt = os.time()
    end
    if not self:Cache(payload, sync) then return end
    self.ready, self.blocked, self.conflict = true, false, false
    self.sending = nil
    self.chooseCloud = false
    self.attempts = 0
    self.retryUntil = 0
    self.nextAttempt = self.clock + (sync.pendingRevision and 0.5 or 30)
    if not alreadyLoaded or merged or updated then self.onLoad(self.localPayload) end
    self:Status(sync.pendingRevision and "pending" or "synced", sync.pendingRevision and "正在同步合并后的成就…" or "家谱已与云端同步")
end

function CloudSave:Conflict(remote)
    self.remote = remote
    self.blocked, self.conflict = true, true
    self:Status("conflict", "云端和本机都有一份进度，请选择要继续的家谱。")
end

function CloudSave:Reconcile(remote)
    self.remote = remote
    if self.chooseCloud then
        if remote then self:Adopt(remote) else self:Fail("云端家谱暂时无法读取，请重试。") end
        return
    end
    local payload = self.localPayload
    if not payload then
        if remote then self:Adopt(remote); return end
        if self.localInvalid then
            self.blocked = true
            self:Status("invalid", "本机家谱无法读取，云端暂无可恢复进度，已停止覆盖。")
            return
        end
        local wasReady = self.ready
        self.ready, self.blocked, self.conflict = true, false, false
        self.nextAttempt = self.clock + 30
        self.attempts, self.retryUntil = 0, 0
        if not wasReady then self.onLoad(nil) end
        self:Status("ready", "游戏进度将自动保存到 TapTap 账号")
        return
    end
    local sync = payload.cloudSync
    if not sync then
        if remote then self:Conflict(remote); return end
        self.blocked = false
        local metadata = self:NextMetadata()
        if not self:Cache(payload, metadata) then return end
        sync = self.localPayload.cloudSync
    end
    local head = revision(remote)
    if sync.pendingRevision and head == sync.pendingRevision then
        self:Adopt(remote)
        return
    end
    if sync.previousRevision and head == sync.previousRevision then
        local metadata = State.Copy(sync)
        metadata.baseRevision, metadata.previousRevision = head, nil
        if not self:Cache(payload, metadata) then return end
        sync = metadata
    end
    if head ~= sync.baseRevision then
        if not sync.pendingRevision and remote and descendsFrom(remote, sync.baseRevision) then
            self:Adopt(remote)
        else
            self:Conflict(remote)
        end
        return
    end
    local wasReady = self.ready
    self.ready, self.blocked, self.conflict = true, false, false
    if not wasReady then self.onLoad(self.localPayload) end
    if sync.pendingRevision then
        self:Upload()
    else
        self.attempts = 0
        self.retryUntil = 0
        self.nextAttempt = self.clock + 30
        self:Status("synced", "家谱已与云端同步")
    end
end

function CloudSave:Sync()
    if self.busy or self.owner == "" or self.stopped or ownerId() ~= self.owner then return end
    self.forceRead = false
    self:Status("reading", self.ready and "正在核对云端进度…" or "正在读取云端家谱…")
    self:Request(function(events) clientCloud:Get(self.key, events) end, function(values)
        if type(values) ~= "table" then self:Fail("云端返回内容无效。") return end
        local remote, message = decode(values[self.key], self.owner)
        if message then self.blocked = true; self:Fail(message); return end
        self:Reconcile(remote)
    end)
end

function CloudSave:Upload()
    local payload = assert(self.localPayload)
    local sync = assert(payload.cloudSync)
    local data = State.Copy(payload)
    data.cloudSync, data.saveRevision, data.importReceipt = nil, nil, nil
    local envelope = {
        format = 1, ownerId = self.owner, revision = sync.pendingRevision,
        parentRevision = sync.baseRevision, updatedAt = sync.savedAt, data = cjson.encode(data),
    }
    if #envelope.data > 15000000 then
        self.blocked = true
        self:Status("invalid", "家谱大小超出云端读取范围，已保留本机进度并停止上传。")
        return
    end
    self.nextUploadAt = self.clock + math.max(0.5, #envelope.data * 3 * 60 / (40 * 1024 * 1024))
    envelope.ancestors = {}
    if sync.baseRevision ~= "" then table.insert(envelope.ancestors, sync.baseRevision) end
    for _, ancestor in ipairs(self.remote and self.remote.ancestors or {}) do
        if #envelope.ancestors >= 64 then break end
        table.insert(envelope.ancestors, ancestor)
    end
    self.sending = envelope
    self:Status("writing", "正在自动保存到云端…")
    self:Request(function(events) clientCloud:Set(self.key, envelope, events) end, function()
        self:Request(function(events) clientCloud:Get(self.key, events) end, function(values)
            local remote, message = decode(type(values) == "table" and values[self.key] or false, self.owner)
            if message then self.blocked = true; self:Fail(message); return end
            if revision(remote) ~= envelope.revision or remote.data ~= envelope.data then
                self:Conflict(remote)
                return
            end
            local latest = assert(self.localPayload)
            local metadata = State.Copy(latest.cloudSync)
            metadata.baseRevision, metadata.previousRevision = envelope.revision, nil
            if metadata.pendingRevision == envelope.revision then metadata.pendingRevision = nil end
            if not self:Cache(latest, metadata) then return end
            self.sending = nil
            self.attempts = 0
            self.retryUntil = 0
            self.nextAttempt = self.clock + (metadata.pendingRevision and 0.5 or 30)
            self:Status(metadata.pendingRevision and "pending" or "synced",
                metadata.pendingRevision and "正在自动保存到云端…" or "家谱已自动保存到云端")
        end)
    end)
end

function CloudSave:Resolve(useCloud)
    if not self.conflict or self.busy then return end
    self.chooseCloud = useCloud
    if not useCloud then
        local payload = State.Copy(assert(self.localPayload))
        Achievements.Merge(payload.profile, self.remote and self.remote.payload.profile)
        Achievements.Update(payload.profile, payload.run)
        self.blocked = false
        local metadata = self:NextMetadata()
        metadata.baseRevision, metadata.previousRevision = revision(self.remote), nil
        if not self:Cache(payload, metadata) then return end
        self.conflict = false
        self.onLoad(self.localPayload)
        self.blocked = true
    end
    self:Sync()
end

function CloudSave:Retry()
    self.forceRead = true
    self.retryUntil = 0
    self.nextAttempt = self.clock
end

function CloudSave:Update(dt, allowRefresh)
    if self.stopped then return end
    if not clientCloud or clientCloud.mapName ~= self.project then
        self:Stop()
        self.blocked = true
        error("云存档游戏项目已变化，请重新打开游戏。")
    end
    self.clock = self.clock + dt
    local owner = ownerId()
    if owner ~= self.owner then
        self.requestId = self.requestId + 1
        self.owner, self.ready, self.blocked, self.busy = owner, false, true, false
        self.conflict, self.sending, self.remote, self.chooseCloud = false, nil, nil, false
        self.nextAttempt, self.attempts, self.retryUntil, self.nextUploadAt = self.clock, 0, 0, 0
        if owner == "" then
            self.stopped = true
            error("TapTap 登录会话已结束，请重新启动游戏完成引擎登录。")
        end
        State.UsePlayerStorage(owner, self.storageNamespace)
        local payload, _, status = State.Load()
        self.localInvalid = status == "invalid" or (status == "missing" and self.legacyInvalid == true)
        self.legacyInvalid = false
        if not payload and status == "missing" and self.legacy
            and (not self.legacy.cloudSync or self.legacy.cloudSync.ownerId == owner) then payload = self.legacy end
        self.legacy = nil
        self.localPayload = payload
        if payload and payload.cloudSync and not validSync(payload.cloudSync, owner) then
            self.localInvalid, self.localPayload = true, nil
            self:Status("invalid", "本机家谱账号信息无效，已停止同步。")
            return
        end
        self:Status("connecting", "正在读取 TapTap 账号中的家谱…")
    end
    if self.state == "invalid" and not self.forceRead then return end
    if self.busy then
        if self.clock >= self.deadline then self:Fail("云端同步超时，当前进度尚未完成同步。") end
        return
    end
    if self.conflict and not self.chooseCloud and not self.forceRead then return end
    if self.clock < self.nextAttempt then return end
    local sync = self.localPayload and self.localPayload.cloudSync
    if sync and sync.pendingRevision and self.clock < self.nextUploadAt then return end
    if not self.ready or self.blocked or self.state == "error" or self.forceRead or (sync and sync.pendingRevision) or allowRefresh then self:Sync() end
end

function CloudSave:Stop()
    self.stopped = true
    self.requestId = self.requestId + 1
end

return CloudSave
