---@diagnostic disable: undefined-global
local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Opening = require "Jiaye.Opening"
local State = require "Jiaye.State"

local app_ = nil

local function GeneratedRun(profile)
    for seed = 1, 4096 do
        local draft = Opening.Generate(profile, seed, "mortal")
        if draft and #draft.members >= 3 then
            draft.members[1].name = "南宫长乐甲乙丙丁戊己庚辛壬癸子丑寅卯"
            local run, issues = State.NewRun(draft, profile)
            if run then return draft, run end
            error(table.concat(issues or {}, "；"))
        end
    end
    error("未找到可供页面验收的真实家庭。")
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    local profile = State.NewProfile()
    local draft, run = GeneratedRun(profile)
    app_ = App.New()
    app_.profile = profile
    app_.draft = draft
    app_.run = run
    app_.screen = "game"
    app_.gameTab = "family"
    app_:Render()
    print("T09_PREVIEW_READY 真实生成家庭仅用于页面验收，未写入本地存档。")
end

function Stop()
    UI.Shutdown()
end
