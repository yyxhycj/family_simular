local UI = require "urhox-libs/UI"
local State = require "Jiaye.State"
local App = require "Jiaye.App"
local Visual = require "Jiaye.Visual"
local Definitions = require "Jiaye.AchievementDefinitions"
local Tap = require "Jiaye.TapAchievements"
local CloudSave = require "Jiaye.CloudSave"
local Opening = require "Jiaye.Opening"
local Simulation = require "Jiaye.Simulation"
local cjson = require "cjson"

---@type table
local app = {}
---@type table
local saved = {}
---@type table?
local reporter = nil
local elapsed, finished = 0, false
local response = ""

function Start()
    UI.Init({ theme = Visual.Theme(), scale = UI.Scale.DEFAULT })
    State.UseVerificationStorage("achievements")
    local payload = State.Load()
    local fresh = false
    for _, argument in ipairs(GetArguments()) do if argument == "-tap_fresh" then fresh = true end end
    if not payload or fresh then
        app = App.New()
        app.profile, app.run = State.NewProfile(), nil
        app.draft = assert(Opening.Generate(app.profile, 20261021, "mortal"))
        app.screen = "opening"
        app:StartRun()
        assert(app.run and not app.unsaved, "验收家族未能正式建立并保存。")
        assert(app:RunAction(function(run, profile) return Simulation.AdvanceYear(run, profile) end), "验收家族未完成真实年度结算。")
        assert(not app.unsaved, "真实年度结算未能保存。")
        payload = assert(State.Load(), "真实年度结算后无法回读。")
    end
    saved = assert(payload)
    assert(saved.profile.achievements["family.first_year"], "验收存档缺少真实年度成就。")
    local rows = {}
    for _, definition in ipairs(Definitions.All) do
        if definition.enabled then
            assert(definition.platformId:match("^[a-zA-Z0-9]+$") and #definition.platformId <= 40, "平台 ID 不符合规则。")
            rows[#rows + 1] = { achievementId = definition.platformId, localId = definition.id, name = definition.name,
                description = definition.condition, hidden = definition.hidden, incremental = false }
        end
    end
    assert(#rows == 66, "关闭剧情进入了平台配置。")
    print("TAPTAP_ACHIEVEMENT_CONFIG " .. cjson.encode(rows))
    app = App.New()
    app:Render()
    app:OpenAchievements()
    local owner = CloudSave.GetOwnerId()
    if not sdk then
        response = "unavailable current_host_has_no_sdk"
    elseif owner ~= "" and type(clientCloud.mapName) == "string" and clientCloud.mapName ~= "" then
        reporter = Tap.New(function() end)
        reporter:Bind(saved.profile, owner, clientCloud.mapName)
    else
        -- 使用真实 SDK 检查当前宿主回调，只有实际获得的初岁会被提交。
        sdk:RegisterAchievementListener({
            onSuccess = function(result) response = "success " .. cjson.encode(result) end,
            onFailure = function(code, reason) response = "failure " .. tostring(code) .. " " .. cjson.encode(reason) end,
        })
        sdk:SetAchievementToastEnabled(false)
        sdk:UnlockAchievement(Definitions.ById["family.first_year"].platformId)
    end
    SubscribeToEvent("Update", "TapAchievementsAcceptanceUpdate")
end

function TapAchievementsAcceptanceUpdate(_, eventData)
    if finished then return end
    local dt = eventData:GetFloat("TimeStep")
    elapsed = elapsed + dt
    if reporter then
        reporter:Update(dt)
        local pending, confirmed = reporter:Counts()
        if pending == 0 then
            print("TAPTAP_ACHIEVEMENT_ONLINE_PASS " .. cjson.encode({ confirmed = confirmed, sdk = true }))
            finished = true
        elseif reporter.lastError ~= "" and elapsed >= 8 then
            assert(pending > 0 and Opening.Equal(State.Load().profile, saved.profile), "失败上报丢失了待补报依据。")
            print("TAPTAP_ACHIEVEMENT_ONLINE_BLOCKED " .. reporter.lastError)
            print("TAPTAP_ACHIEVEMENT_RETENTION_PASS " .. cjson.encode({ pending = pending, confirmed = confirmed }))
            finished = true
        end
    elseif response ~= "" or elapsed >= 8 then
        print("TAPTAP_ACHIEVEMENT_HOST_RESULT " .. (response ~= "" and response or "no_callback"))
        assert(Opening.Equal(State.Load().profile, saved.profile), "宿主接口检查改写了本地达成依据。")
        print("TAPTAP_ACHIEVEMENT_LOCAL_PASS " .. cjson.encode({ definitions = 83, configured = 66, savedEvidenceUnchanged = true }))
        finished = true
    end
    if elapsed >= 120 and not finished then print("TAPTAP_ACHIEVEMENT_ONLINE_BLOCKED timeout"); finished = true end
    if finished then
        if reporter then reporter:Stop() elseif sdk then sdk:UnregisterAchievementListener(); sdk:SetAchievementToastEnabled(true) end
        local inspect = false
        for _, argument in ipairs(GetArguments()) do if argument == "-achievements_inspect" then inspect = true end end
        if not inspect then engine:Exit() end
    end
end

function Stop()
    if reporter then reporter:Stop() end
    UI.Shutdown()
end
