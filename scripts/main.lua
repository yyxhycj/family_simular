-- 《家业》：多代、全员可安排的家族人生模拟器。
-- 基于 UrhoX scaffold-2d.lua 建立：纯 UI、无物理、手机优先。
---@diagnostic disable: undefined-global -- graphics is an UrhoX runtime global.

local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Visual = require "Jiaye.Visual"

---@type table?
local app_ = nil

function Start()
    graphics.windowTitle = "家业 · 凡世王朝"
    UI.Init({
        theme = Visual.Theme(),
        scale = UI.Scale.DPR,
    })
    app_ = App.New()
    app_:Render()
    print("《家业》已启动：随机家庭、对象编辑与家族生活。")
end

function Stop()
    UI.Shutdown()
end
