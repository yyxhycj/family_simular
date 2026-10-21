local Definitions = require "Jiaye.AchievementDefinitions"
local CloudSave = require "Jiaye.CloudSave"

local Tap = {}
Tap.__index = Tap

function Tap.New(onChange)
    local self = setmetatable({}, Tap)
    self:Init(onChange)
    return self
end

function Tap:Init(onChange)
    assert(sdk and type(sdk.UnlockAchievement) == "function" and type(sdk.RegisterAchievementListener) == "function"
        and type(sdk.UnregisterAchievementListener) == "function" and type(sdk.SetAchievementToastEnabled) == "function"
        and type(sdk.ShowAchievements) == "function", "当前引擎缺少 TapTap 成就接口。")
    self.onChange = onChange
    self.owner, self.project = "", ""
    self.clock, self.nextRequest = 0, 0
    self.pending, self.confirmed = {}, {}
    self.inflight = ""
    self.deadline = 0
    self.stopped = false
    self.message = "登录并读取家谱后，自动同步已达成成就。"
    self.lastError = ""
    sdk:RegisterAchievementListener({
        onSuccess = function(result) self:Success(result) end,
        onFailure = function(code, reason) self:Failure(code, reason) end,
    })
end

function Tap:Current()
    return not self.stopped and self.owner ~= "" and CloudSave.GetOwnerId() == self.owner and clientCloud.mapName == self.project
end

function Tap:Status(message)
    self.message = message
    self.onChange()
end

function Tap:Bind(profile, owner, project, added)
    assert(owner ~= "" and owner == CloudSave.GetOwnerId() and project == clientCloud.mapName, "成就同步的账号或项目不一致。")
    if self.stopped then return end
    if self.owner ~= owner or self.project ~= project then
        self.owner, self.project = owner, project
        self.pending, self.confirmed, self.inflight = {}, {}, ""
        self.nextRequest, self.lastError = self.clock, ""
    end
    local fresh = {}
    for _, id in ipairs(added or {}) do fresh[id] = true end
    -- 已写入存档的达成集合就是补报依据；重启和换设备后由平台按账号去重。
    for _, definition in ipairs(Definitions.All) do
        local id = definition.id
        if definition.enabled and profile.achievements[id] and not self.confirmed[id] and not self.pending[id] then
            self.pending[id] = { platformId = definition.platformId, quiet = not fresh[id], attempts = 0, nextAt = self.clock }
        end
    end
    for id in pairs(self.pending) do if not profile.achievements[id] then self.pending[id] = nil end end
    if self.inflight ~= "" and not self.pending[self.inflight] then self.inflight = ""; sdk:SetAchievementToastEnabled(true) end
    if self.inflight == "" and self.lastError == "" then self:Refresh() end
end

function Tap:Counts()
    local pending, confirmed = 0, 0
    for _ in pairs(self.pending) do pending = pending + 1 end
    for _ in pairs(self.confirmed) do confirmed = confirmed + 1 end
    return pending, confirmed
end

function Tap:Refresh()
    local pending, confirmed = self:Counts()
    self:Status(pending > 0 and ("有 " .. pending .. " 项成就等待同步到 TapTap。")
        or confirmed > 0 and "已达成成就已同步到 TapTap。" or "尚无待同步的成就。")
end

function Tap:Success(result)
    if not self:Current() or result.operation ~= "unlock" or result.achievementType ~= "normal" then return end
    local definition = Definitions.ByPlatformId[result.achievementId]
    local entry = definition and self.pending[definition.id]
    if not definition or not definition.enabled or not entry or not entry.requested then return end
    self.confirmed[definition.id], self.pending[definition.id] = true, nil
    if self.inflight == definition.id then self.inflight = ""; sdk:SetAchievementToastEnabled(true) end
    self.lastError = ""
    self.nextRequest = self.clock + 0.5
    print("TAPTAP_ACHIEVEMENT_CONFIRMED " .. result.achievementId)
    self:Refresh()
end

function Tap:Failure(code, reason)
    if not self:Current() then return end
    if reason.achievementId == "" then
        print("TAPTAP_ACHIEVEMENT_PAGE_ERROR " .. tostring(code) .. " " .. reason.message)
        self:Status("暂时无法打开 TapTap 成就页，请稍后重试。")
        return
    end
    local definition = Definitions.ByPlatformId[reason.achievementId]
    if not definition or definition.id ~= self.inflight then return end
    self:RetryLater(code, reason.message)
end

function Tap:RetryLater(code, message)
    ---@type table
    local entry = self.pending[self.inflight]
    assert(entry, "成就上报记录缺失。")
    entry.attempts = entry.attempts + 1
    entry.nextAt = self.clock + math.min(60, 2 ^ math.min(entry.attempts, 6))
    self.nextRequest, self.inflight = entry.nextAt, ""
    self.lastError = tostring(code) .. "：" .. message
    sdk:SetAchievementToastEnabled(true)
    print("TAPTAP_ACHIEVEMENT_RETRY " .. entry.platformId .. " " .. self.lastError)
    self:Status("成就尚未同步到 TapTap，将自动重试。")
end

function Tap:Update(dt)
    if self.stopped then return end
    self.clock = self.clock + dt
    if self.owner == "" then return end
    if not self:Current() then self:Stop(); return end
    if self.inflight ~= "" then
        if self.clock >= self.deadline then self:RetryLater("timeout", "平台未返回确认") end
        return
    end
    if self.clock < self.nextRequest then return end
    for _, definition in ipairs(Definitions.All) do
        local entry = self.pending[definition.id]
        if entry and self.clock >= entry.nextAt then
            self.inflight, self.deadline = definition.id, self.clock + 20
            entry.requested = true
            sdk:SetAchievementToastEnabled(not entry.quiet)
            self:Status("正在同步成就到 TapTap…")
            print("TAPTAP_ACHIEVEMENT_REQUEST " .. entry.platformId)
            sdk:UnlockAchievement(entry.platformId)
            return
        end
    end
end

function Tap:Retry()
    if not self:Current() or self.inflight ~= "" then return end
    self.nextRequest, self.lastError = self.clock, ""
    for _, entry in pairs(self.pending) do entry.nextAt = self.clock end
    self:Refresh()
end

function Tap:Show()
    if not self:Current() then return false end
    sdk:ShowAchievements()
    return true
end

function Tap:Stop()
    if self.stopped then return end
    self.stopped = true
    sdk:UnregisterAchievementListener()
    sdk:SetAchievementToastEnabled(true)
end

return Tap
