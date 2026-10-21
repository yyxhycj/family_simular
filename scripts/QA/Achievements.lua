local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local State = require "Jiaye.State"
local Data = require "Jiaye.Data"
local Visual = require "Jiaye.Visual"
local Simulation = require "Jiaye.Simulation"
local Relics = require "Jiaye.RelicSystem"
local Origin = require "Jiaye.OriginSystem"
local OriginState = require "Jiaye.OriginState"
local Achievements = require "Jiaye.Achievements"
local Definitions = require "Jiaye.AchievementDefinitions"
local Opening = require "Jiaye.Opening"
local cjson = require "cjson"

---@type table
local app = {}
local frames = 0
local beforeView = ""

local function Has(id)
    return app.profile.achievements[id] ~= nil
end

local function Act(action)
    assert(app:RunAction(action), "实际游戏操作失败。")
    assert(not app.unsaved, app.saveMessage)
end

local function Pending()
    while #Simulation.PendingEvents(app.run) > 0 do
        local event = Simulation.PendingEvents(app.run)[1]
        assert(event.type ~= "leader", "验收家族意外缺少族长。")
        Act(function(run, profile) return Simulation.ResolveEvent(run, event.instanceId, "defer", profile) end)
    end
end

local function Year()
    Pending()
    Act(function(run, profile) return Simulation.AdvanceYear(run, profile) end)
end

local function Visit(widget, callback, seen)
    seen = seen or {}
    if seen[widget] then return end
    seen[widget] = true
    callback(widget)
    for _, child in ipairs(widget:GetChildren()) do Visit(child, callback, seen) end
    if widget.GetHitTestChildren then for _, child in ipairs(widget:GetHitTestChildren()) do Visit(child, callback, seen) end end
end

local function ConfirmNewFamily()
    local buttons = {}
    Visit(app.root, function(widget)
        if widget.props.text == "确认开始" and widget.props.onClick then buttons[#buttons + 1] = widget end
    end)
    assert(#buttons == 1, "新家谱确认按钮不唯一。")
    buttons[1].props.onClick(buttons[1])
end

local function Draft(originId, name)
    ---@type table
    local draft = State.NewDraft()
    draft.family, draft.money, draft.grain, draft.land = name, 200, 40, 1
    draft.rulesVersion, draft.relicRulesVersion, draft.originRulesVersion = 2, "1.2", OriginState.VERSION
    draft.originId = originId
    draft.members = { draft.members[1], draft.members[2] }
    draft.members[1].age, draft.members[2].age = 26, 24
    draft.members[1].jobId, draft.members[2].jobId = originId == "military" and "guard" or "craft", "farm"
    for _, member in ipairs(draft.members) do member.experienceId = originId == "military" and "martial" or "craft" end
    if originId == "scholar" then draft.members[1].jobId, draft.members[1].experienceId = "study", "basic" end
    if originId == "plain" then draft.members[1].jobId = "farm" end
    if originId == "merchant" then draft.members[1].jobId, draft.members[1].experienceId = "trade", "trade" end
    if originId ~= "artisan" and originId ~= "military" then draft.money, draft.grain = 120, 32 end
    if originId == "gentry" then draft.money, draft.grain = 40, 16 end
    draft.selectedRelicIds = nil
    local formId = (originId == "military" or originId == "scholar" or originId == "merchant") and "letter.1" or "ruler.1"
    draft.selectedRelicFormIds, draft.relicUsers = { formId }, { [formId] = 1 }
    return draft
end

local function Begin(originId, name, legacy)
    if app.run then app:PrepareNewRun() else app.screen = "opening" end
    app.draft = Draft(originId, name)
    if legacy then
        app.draft.rulesVersion, app.draft.relicRulesVersion, app.draft.originRulesVersion = nil, nil, nil
        app.draft.selectedRelicFormIds, app.draft.relicUsers, app.draft.selectedRelicIds = nil, nil, { "ruler" }
    end
    local issues = State.ValidateDraft(app.draft, app.profile, false)
    assert(#issues == 0, table.concat(issues, "；"))
    app:StartRun()
    if app.startConfirmationOpen then ConfirmNewFamily() end
    assert(app.run and app.run.openingSnapshot.family == name, "新家谱未正式建立。")
    for _, member in ipairs(app.run.members) do
        local id = member.id
        Act(function(run) return Simulation.SetBirthPlan(run, id, false) end)
    end
end

function Start()
    UI.Init({ theme = Visual.Theme(), scale = UI.Scale.DEFAULT })
    State.UseVerificationStorage("achievements")
    app = App.New()
    app.profile, app.run = State.NewProfile(), nil
    Begin("artisan", "成验")
    assert(#Definitions.All == 83 and #Achievements.Visible(app.profile) == 66, "定义数量或关闭范围不一致。")
    assert(not Has("family.first_year"), "正式开局不能提前获得年度成就。")
    local rulerId = app.run.relicInstances[1].instanceId
    Act(function(run) return Origin.Execute(run, "start", { memberId = 1 }) end)
    assert(not Has("origin.workshop") and not Has("estate.settled_order"), "接单不能提前获得完工成就。")
    Year()
    assert(Has("family.first_year") and not Has("origin.workshop"), "初年或待领取状态判定不正确。")
    Act(function(run) return Origin.Execute(run, "take_cash") end)
    assert(Has("origin.workshop") and Has("estate.settled_order") and Has("history.story"), "实际回款或连续故事未入册。")
    print("ACHIEVEMENTS_PASS 1 年度、接单、待领取、实际回款与故事收束")

    Act(function(run, profile) return Relics.Start(run, profile, "ruler.trace_mark", { instanceId = rulerId, executorId = 1, route = "slow" }) end)
    assert(not Has("relic.ruler.mark"), "受理查访不能提前获得确证成就。")
    Year()
    local taskId = app.run.relicTasks[#app.run.relicTasks].id
    local paid = cjson.encode(app.run.relicTasks[#app.run.relicTasks].paid)
    Act(function(run) return Relics.Pause(run, taskId) end)
    Act(function(run) return Relics.Resume(run, taskId, { executorId = 2 }) end)
    Act(function(run) return Simulation.AppointLeader(run, 2) end)
    assert(not Has("family.succession"), "新任尚未经营一年不能获得交接成就。")
    Act(function(run) return Simulation.SetJob(run, 1, "rest") end)
    Year()
    assert(Has("family.succession") and Has("relic.task_successor") and Has("relic.ruler.mark") and Has("relic.upgraded"), "继任或换人续办未正确达成。")
    assert(cjson.encode(app.run.relicTasks[#app.run.relicTasks].paid) == paid, "换人续办改变了原费用。")
    Act(function(run, profile) return Relics.Start(run, profile, "ruler.copy_plan", { instanceId = rulerId, executorId = 1 }) end)
    assert(Has("relic.ruler.plan"), "真实誊图未获得成就。")
    Act(function(run) return Simulation.SetJob(run, 1, "craft") end)
    Year()
    assert(Has("family.retired_leader") and Has("growth.return_after_rest"), "卸任生活或休养后重返工作未正确入册。")
    print("ACHIEVEMENTS_PASS 2 真实任期、休养、信物升阶与原任务换人续办")

    Act(function(run) return Simulation.BuyAsset(run, "land") end)
    Act(function(run) return Simulation.BuyAsset(run, "workshop") end)
    Act(function(run) return Simulation.UpgradeHome(run) end)
    assert(not Has("estate.bought_harvest") and not Has("estate.business") and not Has("estate.home_upgrade"), "购置后尚未生活经营不能提前达成。")
    Act(function(run) return Simulation.Adopt(run, 1) end)
    local childId = app.run.members[#app.run.members].id
    assert(not Has("family.new_member"), "入户后尚未生活一年不能提前达成。")
    Year()
    assert(Has("estate.bought_harvest") and Has("estate.home_upgrade") and Has("family.new_member"), "收成、入住或新成员实际年度未入册。")
    Year()
    assert(Has("estate.business"), "作坊实际经营两年未达成。")
    while app.run.yearIndex < 9 do Year() end
    Act(function(run) return Simulation.BuyAsset(run, "shop") end)
    Act(function(run) return Simulation.SetJob(run, 2, "trade") end)
    while app.run.yearIndex < 10 do Year() end
    Act(function(run) return Simulation.SetJob(run, childId, "apprentice") end)
    while State.FindMember(app.run.members, childId).age < 18 do Year() end
    assert(Has("family.grown_here"), "本局长大成年经历未入册。")
    Act(function(run) return Simulation.SetJob(run, childId, "craft") end)
    Act(function(run) return Relics.AssignUser(run, rulerId, childId) end)
    assert(not Has("relic.handed_down"), "转交后尚未实际使用不能提前达成。")
    Year()
    assert(Has("relic.handed_down") and Has("estate.shop_workshop") and Has("estate.two_incomes"), "两代使用或双业经营未正确达成。")
    while app.run.yearIndex < 20 do Year() end
    assert(Has("family.twenty_years") and Has("growth.expert") and Has("growth.persistence"), "经营年数或实际成长未入册。")
    print("ACHIEVEMENTS_PASS 3 局内置产、住宅入住、收养成长与两代真实使用")

    Pending()
    Act(function(run, profile) return Simulation.ClaimEnding(run, "peaceful", profile) end)
    assert(Has("history.ending"), "正式发展终章未入册。")
    local first = State.Copy(app.profile)
    local firstId = app.run.runId
    Begin("military", "续验")
    assert(app.run.runId ~= firstId and Has("history.ending"), "新家族身份或跨局收藏未保留。")
    Act(function(run) return Origin.Execute(run, "safe", { memberId = 1 }) end)
    Act(function(run) return Simulation.MoveFamily(run, "border") end)
    assert(not Has("travel.first_year") and not Has("travel.kept_order"), "迁居当下不能提前获得居住或订单完成成就。")
    Year()
    assert(Has("origin.escort") and Has("travel.first_year") and Has("travel.kept_order"), "稳路真实交付或迁居前订单未入册。")
    while app.run.yearIndex < 15 do Year() end
    assert(Has("history.two_families"), "两户实际经营经历未入册。")
    Pending()
    Act(function(run, profile) return Simulation.ClaimEnding(run, "grain", profile) end)
    assert(Has("history.different_endings"), "不同家族的不同发展终章未入册。")
    local merged = State.Copy(first)
    assert(Achievements.Merge(merged, app.profile), "跨局收藏没有合并。")
    assert(not Achievements.Merge(merged, app.profile), "相同收藏重复合并产生变化。")
    assert(merged.achievements["history.different_endings"] and merged.achievements["history.two_families"], "合并丢失跨局成就。")
    assert(Has("travel.settled"), "迁居后真实安居未入册。")
    print("ACHIEVEMENTS_PASS 4 两户真实经营、不同终章与收藏幂等合并")

    Begin("scholar", "阅验")
    Act(function(run) return Origin.Execute(run, "borrow", { memberId = 1 }) end)
    assert(not Has("origin.scroll") and not Has("travel.returned_loan"), "借入不能提前触发归还。")
    Year()
    Act(function(run) return Origin.Execute(run, "return") end)
    assert(Has("origin.scroll") and Has("travel.returned_loan"), "有效借阅及原物归还未入册。")
    Begin("plain", "穗验")
    Act(function(run) return Origin.Execute(run, "start", { memberId = 1 }) end)
    Year()
    assert(not Has("origin.seed"), "尚未决定粮种去向不能提前达成。")
    Act(function(run) return Origin.Execute(run, "keep_food") end)
    assert(Has("origin.seed"), "真实试种与去向选择未入册。")
    Begin("merchant", "账验")
    Act(function(run) return Origin.Execute(run, "audit", { memberId = 1 }) end)
    assert(not Has("origin.accounts"), "只核实旧欠不能触发回款。")
    Act(function(run) return Simulation.MoveFamily(run, "port") end)
    Act(function(run) return Origin.Execute(run, "settle") end)
    assert(Has("origin.accounts") and Has("travel.old_contact"), "真实旧欠回款与原联系人新往来未入册。")
    Begin("gentry", "引验")
    Act(function(run) return Origin.Execute(run, "start", { memberId = 1 }) end)
    Year()
    Act(function(run) return Origin.Execute(run, "work_referral", { memberId = 1 }) end)
    assert(not Has("origin.referral"), "获得引荐资格不能触发实际帮助。")
    Year()
    assert(Has("origin.referral") and Has("history.five_stories"), "实际引荐帮助或五个不同故事收束未入册。")
    print("ACHIEVEMENTS_PASS 5 六个背景、迁居旧识、原物归还与不同故事收束")

    Begin("artisan", "旧验", true)
    Year()
    assert(Achievements.Progress(app.profile, app.run)[22].current == 0, "旧规则的开局田地误计为购买。")
    Act(function(run) return Simulation.BuyAsset(run, "land") end)
    Act(function(run) return Simulation.BuyAsset(run, "workshop") end)
    Act(function(run) return Simulation.UpgradeHome(run) end)
    Year(); Year()
    local legacyProgress = Achievements.Progress(app.profile, app.run)
    assert(legacyProgress[22].current == 1 and legacyProgress[23].current == 2 and legacyProgress[24].current == 1, "旧规则年度的置产、经营或入住依据缺失。")
    print("ACHIEVEMENTS_PASS 6 旧规则真实年度的置产、经营与入住")

    local expected = State.Copy({ profile = app.profile, draft = app.draft, run = app.run })
    local resumed = App.New()
    assert(Opening.Equal(resumed.profile, expected.profile) and Opening.Equal(resumed.run, expected.run), "重新读取丢失成就或实际经历。")
    local raw = assert(State.Export(app.profile, app.draft, app.run))
    local candidate = assert(State.PreflightImport(raw))
    assert(State.CommitImport(candidate))
    local ok, _, status = State.CommitImport(candidate)
    assert(ok and status == "duplicate", "同局重复导入未被识别。")
    assert(Opening.Equal(State.Load().profile, expected.profile), "重复导入改变了成就记录。")
    app = App.New()
    app:Render()
    beforeView = cjson.encode({ profile = app.profile, run = app.run })
    app:OpenAchievements()
    Visit(app.root, function(widget)
        local text = widget.props.text or ""
        assert(not text:find("83", 1, true) and not text:find("她的落款", 1, true), "界面泄露关闭条目。")
    end)
    print("ACHIEVEMENTS_PASS 7 磁盘回读、同局导入去重与隐藏界面")
    SubscribeToEvent("Update", "AchievementsAcceptanceUpdate")
end

function AchievementsAcceptanceUpdate()
    frames = frames + 1
    if frames == 12 then
        UI.Layout()
        assert(cjson.encode({ profile = app.profile, run = app.run }) == beforeView, "查看成就改写了家谱或随机数。")
        print("ACHIEVEMENTS_VERIFIED " .. cjson.encode({ definitions = #Definitions.All, visible = #Achievements.Visible(app.profile), firstFamilyYears = 20,
            secondFamilyYears = 15, readOnlyView = true, saveSchemaVersion = State.SAVE_SCHEMA_VERSION }))
        local inspect = false
        for _, argument in ipairs(GetArguments()) do if argument == "-achievements_inspect" then inspect = true end end
        if not inspect then engine:Exit() end
    end
end

function Stop()
    UI.Shutdown()
end
