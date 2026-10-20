local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local State = require "Jiaye.State"
local Opening = require "Jiaye.Opening"
local Simulation = require "Jiaye.Simulation"
local Visual = require "Jiaye.Visual"
local cjson = require "cjson"

---@type table
local app = nil
local key = ""
local phase = 0
local elapsed = 0
local deadline = 0
local expected = {}
local localBranch = {}
local remoteBranch = {}

local function snapshot()
    return State.Copy({ profile = app.profile, draft = app.draft, run = app.run })
end

local function equalPayload(payload, wanted)
    assert(payload and Opening.Equal(payload.profile, wanted.profile), "收藏不一致")
    assert(Opening.Equal(payload.draft, wanted.draft), "开局草案不一致")
    assert(Opening.Equal(payload.run, wanted.run), "家谱进度不一致")
end

local function step(nextPhase, name)
    phase, deadline = nextPhase, elapsed + 90
    print("CLOUD_ACCEPTANCE " .. cjson.encode({ phase = phase, step = name }))
end

local function switchDevice(name)
    if app then app.cloud:Stop() end
    app = App.New()
    app:EnableCloudSave(key)
    app.cloud.storageNamespace = key .. "_" .. name
    app:Render()
end

local function changeJob(excluded)
    local member = assert(State.FindMember(app.run.members, app.run.leaderId))
    for _, job in ipairs({ "rest", "farm", "home" }) do
        if job ~= member.jobId and job ~= excluded and State.CanUseJob(member, job) then
            assert(app:RunAction(function(run) return Simulation.SetJob(run, member.id, job) end))
            return job
        end
    end
    error("没有可用的人物安排")
end

local function synced()
    return app.cloud.ready and not app.cloud.blocked and not app.cloud.busy
        and app.cloud.state == "synced" and not app.cloud.localPayload.cloudSync.pendingRevision
end

function Start()
    UI.Init({ theme = Visual.Theme(), scale = UI.Scale.DEFAULT })
    key = "jiaye_cloud_acceptance_" .. tostring(os.time()) .. "_" .. tostring(math.random(1, 2147483647))
    switchDevice("a")
    step(1, "等待真实账号云端读取")
    SubscribeToEvent("Update", "CloudAcceptanceUpdate")
end

function CloudAcceptanceUpdate(_, eventData)
    local dt = eventData:GetFloat("TimeStep")
    elapsed = elapsed + dt
    app:UpdateCloud(dt)
    assert(elapsed < deadline, "云端验收超时，阶段 " .. tostring(phase) .. "：" .. app.cloud.message)
    if phase == 1 and app.cloud.ready then
        assert(not app.run and not app.cloud.localPayload, "独立验收账号空间已有进度")
        app:PrepareNewRun()
        app:StartRun()
        assert(app.run, "新家谱未建立")
        expected = snapshot()
        step(2, "新局自动上传并回读")
    elseif phase == 2 and synced() then
        equalPayload(app.cloud.localPayload, expected)
        changeJob()
        expected = snapshot()
        step(3, "人物安排自动上传")
    elseif phase == 3 and synced() then
        switchDevice("b")
        step(4, "空白本机读取同账号家谱")
    elseif phase == 4 and synced() then
        equalPayload(snapshot(), expected)
        print("CLOUD_ACCEPTANCE_PASS new_device_restores_full_profile_draft_run")
        changeJob()
        expected = snapshot()
        step(5, "第二台设备继续游戏")
    elseif phase == 5 and synced() then
        switchDevice("a")
        step(6, "旧设备读取较新的云端进度")
    elseif phase == 6 and synced() then
        equalPayload(snapshot(), expected)
        print("CLOUD_ACCEPTANCE_PASS existing_device_refreshes_remote_progress")
        changeJob()
        localBranch = snapshot()
        switchDevice("b")
        step(7, "保留未上传本机进度，另一台设备继续")
    elseif phase == 7 and synced() then
        local excluded = State.FindMember(localBranch.run.members, localBranch.run.leaderId).jobId
        changeJob(excluded)
        remoteBranch = snapshot()
        step(8, "另一台设备保存分叉进度")
    elseif phase == 8 and synced() then
        switchDevice("a")
        step(9, "检测本机与云端分叉")
    elseif phase == 9 and app.cloud.conflict then
        equalPayload(app.cloud.localPayload, localBranch)
        equalPayload(app.cloud.remote.payload, remoteBranch)
        assert(app.root:FindById("cloud-save-use-local") and app.root:FindById("cloud-save-use-remote"))
        app.cloud:Resolve(true)
        step(10, "确认使用云端家谱")
    elseif phase == 10 and synced() then
        equalPayload(snapshot(), remoteBranch)
        print("CLOUD_ACCEPTANCE_PASS conflict_select_remote")
        changeJob()
        localBranch = snapshot()
        switchDevice("b")
        step(11, "保留第二份本机分叉")
    elseif phase == 11 and synced() then
        local excluded = State.FindMember(localBranch.run.members, localBranch.run.leaderId).jobId
        changeJob(excluded)
        remoteBranch = snapshot()
        step(12, "保存第二份云端分叉")
    elseif phase == 12 and synced() then
        switchDevice("a")
        step(13, "确认保留本机家谱")
    elseif phase == 13 and app.cloud.conflict then
        equalPayload(app.cloud.localPayload, localBranch)
        equalPayload(app.cloud.remote.payload, remoteBranch)
        app.cloud:Resolve(false)
        assert(app.cloud.blocked, "选择本机后仍需先核对云端版本")
        step(14, "本机选择上传并回读")
    elseif phase == 14 and synced() then
        equalPayload(snapshot(), localBranch)
        switchDevice("c")
        step(15, "全新本机确认冲突选择结果")
    elseif phase == 15 and synced() then
        equalPayload(snapshot(), localBranch)
        print("CLOUD_ACCEPTANCE_PASS conflict_select_local_and_restore")
        changeJob()
        step(16, "上传期间继续安排族人")
    elseif phase == 16 and app.cloud.state == "writing" and app.cloud.busy then
        changeJob()
        expected = snapshot()
        step(17, "等待较新的安排自动续传")
    elseif phase == 17 and synced() then
        switchDevice("d")
        step(18, "全新本机核对最后一次安排")
    elseif phase == 18 and synced() then
        equalPayload(snapshot(), expected)
        print("CLOUD_ACCEPTANCE_PASS inflight_changes_preserved_and_restored")
        print("CLOUD_ACCEPTANCE_ALL_PASS " .. cjson.encode({ key = key, checks = 5, storage = "independent_local_namespaces", transport = "clientCloud" }))
        app.cloud:Stop()
        UnsubscribeFromEvent("Update")
    end
end

function Stop()
    if app and app.cloud then app.cloud:Stop() end
    UI.Shutdown()
end
