-- 《千家纪》：多代、全员可安排的家族人生模拟器。
-- 基于 UrhoX scaffold-2d.lua 建立：纯 UI、无物理、手机优先。
---@diagnostic disable: undefined-global -- graphics is an UrhoX runtime global.

local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local State = require "Jiaye.State"
local Visual = require "Jiaye.Visual"

---@type table?
local app_ = nil

local function IsLocalDevelopment()
    local platform = GetPlatform()
    if platform == "macOS" or platform == "Mac" or platform == "Windows" or platform == "Linux" then
        for _, argument in ipairs(GetArguments()) do
            if argument == "-skip_login" then return true end
        end
    end
    return false
end

function Start()
    local localDevelopment = IsLocalDevelopment()
    if localDevelopment then State.UseDevelopmentStorage() else State.UseGuestStorage() end
    graphics.windowTitle = localDevelopment and "千家纪 · 本地开发" or "千家纪 · 凡世王朝"
    UI.Init({
        theme = Visual.Theme(),
        scale = UI.Scale.DEFAULT,
    })
    app_ = App.New()
    app_.localDevelopment = localDevelopment
    app_:ShowLogin()
    SubscribeToEvent("Update", "HandleCloudSaveUpdate")
    SubscribeToEvent("InputFocus", "HandleCloudSaveFocus")
    print("《千家纪》已启动：请选择 TapTap 登录或游客登录。")
end

function HandleCloudSaveUpdate(_, eventData)
    app_:UpdateCloud(eventData:GetFloat("TimeStep"))
end

function HandleCloudSaveFocus()
    app_:FlushCloud()
end

function Stop()
    if app_ then app_:AutoSave() end
    if app_ and app_.cloud then app_.cloud:Stop() end
    if app_ and app_.tapAchievements then app_.tapAchievements:Stop() end
    UI.Shutdown()
end
