local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local State = require "Jiaye.State"
local Opening = require "Jiaye.Opening"
local Simulation = require "Jiaye.Simulation"
local Visual = require "Jiaye.Visual"
local OriginState = require "Jiaye.OriginState"
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

local function mergedChoice(chosen, other)
    assert(Opening.Equal(app.draft, chosen.draft) and Opening.Equal(app.run, chosen.run), "冲突选择改变了所选家谱")
    for _, profile in ipairs({ chosen.profile, other.profile }) do
        for id in pairs(profile.achievements) do
            local record = app.profile.achievements[id]
            assert(record and (Opening.Equal(record, chosen.profile.achievements[id]) or Opening.Equal(record, other.profile.achievements[id])), "冲突选择丢失已达成成就：" .. id)
        end
        for id, family in pairs(profile.achievementFamilies) do
            assert(app.profile.achievementFamilies[id] and app.profile.achievementFamilies[id].years >= family.years, "冲突选择丢失家族经营经历")
        end
        for id in pairs(profile.achievementStories) do assert(app.profile.achievementStories[id], "冲突选择丢失已收束故事") end
    end
end

local function year()
    while #Simulation.PendingEvents(app.run) > 0 do
        local event = Simulation.PendingEvents(app.run)[1]
        assert(event.type ~= "leader", "验收家族缺少族长")
        assert(app:RunAction(function(run, profile) return Simulation.ResolveEvent(run, event.instanceId, "defer", profile) end))
    end
    assert(app:RunAction(function(run, profile) return Simulation.AdvanceYear(run, profile) end))
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
        ---@type table
        local draft = State.NewDraft()
        draft.family, draft.money, draft.grain, draft.land = "云验", 200, 40, 1
        draft.rulesVersion, draft.relicRulesVersion, draft.originRulesVersion = 2, "1.2", OriginState.VERSION
        draft.members = { draft.members[1], draft.members[2] }
        draft.members[1].age, draft.members[2].age = 26, 24
        draft.members[1].jobId, draft.members[2].jobId = "craft", "farm"
        for _, member in ipairs(draft.members) do member.experienceId = "craft" end
        draft.selectedRelicFormIds, draft.relicUsers = { "ruler.1" }, { ["ruler.1"] = 1 }
        draft.selectedRelicIds = nil
        draft.originId = "artisan"
        app.draft = draft
        app:StartRun()
        assert(app.run, "新家谱未建立")
        for _, member in ipairs(app.run.members) do
            local id = member.id
            assert(app:RunAction(function(run) return Simulation.SetBirthPlan(run, id, false) end))
        end
        expected = snapshot()
        step(2, "新局自动上传并回读")
    elseif phase == 2 and synced() then
        equalPayload(app.cloud.localPayload, expected)
        changeJob()
        year()
        assert(app.profile.achievements["family.first_year"], "真实年度成就未保存")
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
        while app.run.yearIndex < 20 do year() end
        assert(app.profile.achievements["family.twenty_years"], "本机分叉未达成二十春秋")
        localBranch = snapshot()
        switchDevice("b")
        step(7, "保留未上传本机进度，另一台设备继续")
    elseif phase == 7 and synced() then
        local excluded = State.FindMember(localBranch.run.members, localBranch.run.leaderId).jobId
        changeJob(excluded)
        assert(app:RunAction(function(run) return Simulation.MoveFamily(run, "border") end))
        year()
        assert(app.profile.achievements["travel.first_year"] and not app.profile.achievements["family.twenty_years"], "云端分叉成就未形成独立经历")
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
        mergedChoice(remoteBranch, localBranch)
        remoteBranch = snapshot()
        print("CLOUD_ACCEPTANCE_PASS conflict_select_remote")
        changeJob()
        localBranch = snapshot()
        switchDevice("b")
        step(11, "保留第二份本机分叉")
    elseif phase == 11 and synced() then
        local excluded = State.FindMember(localBranch.run.members, localBranch.run.leaderId).jobId
        changeJob(excluded)
        assert(app:RunAction(function(run) return Simulation.UpgradeHome(run) end))
        year()
        assert(app.profile.achievements["estate.home_upgrade"], "云端分叉未达成新檐")
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
        mergedChoice(localBranch, remoteBranch)
        localBranch = snapshot()
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
        UI.SetRoot(UI.Panel {
            width = "100%", height = "100%", padding = 24, gap = 18,
            backgroundColor = { 247, 242, 230, 255 },
            children = {
                Visual.Text("云存档验收通过", { fontSize = 28, fontColor = { 39, 85, 58, 255 } }),
                Visual.Text("真实 TapTap 账号 · clientCloud 读写", { fontSize = 16, whiteSpace = "normal" }),
                Visual.Text("✓ 新局与人物安排自动上传\n✓ 独立本机完整恢复家谱\n✓ 旧设备读取较新进度\n✓ 冲突选择云端或本机进度\n✓ 上传期间的新安排继续同步", {
                    width = "100%", fontSize = 18, whiteSpace = "normal", lineHeight = 1.7,
                }),
                Visual.Text("续玩检查使用独立本机存储会话。", { width = "100%", fontSize = 14, whiteSpace = "normal" }),
                Visual.Text(key, { width = "100%", fontSize = 12, whiteSpace = "normal" }),
            },
        })
    end
end

function Stop()
    if app and app.cloud then app.cloud:Stop() end
    UI.Shutdown()
end
