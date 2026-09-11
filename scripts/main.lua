-- 《家业》：纯文字、多代、全员可安排的家族人生模拟器。
-- 基于 UrhoX scaffold-2d.lua 建立：纯 UI、无物理、手机优先。

local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"

local app_ = nil

function Start()
    graphics.windowTitle = "家业 · 凡世王朝"
    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })
    app_ = App.New()
    app_:Render()
    print("《家业》已启动：本地单人存档、五步开局与凡世家族循环已就绪。")
end

function Stop()
    UI.Shutdown()
end
