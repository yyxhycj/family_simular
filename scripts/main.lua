-- 《千家纪》：多代、全员可安排的家族人生模拟器。
-- 基于 UrhoX scaffold-2d.lua 建立：纯 UI、无物理、手机优先。
---@diagnostic disable: undefined-global -- graphics is an UrhoX runtime global.

local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Visual = require "Jiaye.Visual"

---@type table?
local app_ = nil

function Start()
    graphics.windowTitle = "千家纪 · 凡世王朝"
    UI.Init({
        theme = Visual.Theme(),
        scale = UI.Scale.DEFAULT,
    })
    app_ = App.New()
    app_:EnableCloudSave()
    app_:Render()
    SubscribeToEvent("Update", "HandleCloudSaveUpdate")
    SubscribeToEvent("InputFocus", "HandleCloudSaveFocus")
    print("《千家纪》已启动：随机家庭、对象编辑与家族生活。")
end

function HandleCloudSaveUpdate(_, eventData)
    app_:UpdateCloud(eventData:GetFloat("TimeStep"))
end

function HandleCloudSaveFocus()
    app_:FlushCloud()
end

function Stop()
    if app_ and app_.cloud then app_.cloud:Stop() end
    UI.Shutdown()
end
