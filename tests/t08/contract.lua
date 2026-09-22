-- T08 直接验证生产终局规则、终局快照、只读边界与存档读取；声明式 UI 仅核对已绑定文本。
local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Data = require "Jiaye.Data"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"

local function same(left, right) return cjson.encode(left) == cjson.encode(right) end

local function contains(root, value)
    if type(root.text) == "string" and root.text:find(value, 1, true) then return root end
    for _, child in ipairs(root.children or {}) do
        local result = contains(child, value)
        if result then return result end
    end
end

local function fresh()
    local profile, draft = State.NewProfile(), State.NewDraft()
    local run, issues = State.NewRun(draft, profile)
    assert(run, table.concat(issues or {}, "；"))
    return run, profile, draft
end

local function livingAdult(run, excludedId)
    for _, member in ipairs(run.members) do
        if member.alive and State.IsAdult(member) and member.id ~= excludedId then return member end
    end
end

local function resolvePending(run, profile)
    for _ = 1, 64 do
        local events = Simulation.PendingEvents(run)
        if #events == 0 then return end
        local event = events[1]
        local ok, message
        if event.type == "leader" then
            local successor = assert(livingAdult(run), "继任事件没有在世成年候选。")
            ok, message = Simulation.ResolveLeaderEvent(run, event.instanceId, successor.id)
        else
            ok, message = Simulation.ResolveEvent(run, event.instanceId, "defer", profile)
        end
        assert(ok, message)
    end
    error("待决事件未能在限定步数内处理完。")
end

local function factById(run, factId)
    for _, fact in ipairs(run.facts or {}) do if fact.id == factId then return fact end end
end

local function prepareStableHousehold(run)
    for _, member in ipairs(run.members) do
        if State.IsAdult(member) then
            member.birthPlan = false
            if member.id ~= run.leaderId then
                local ok, message = Simulation.SetJob(run, member.id, "farm")
                assert(ok or member.jobId == "farm", message)
            end
        end
    end
end

local function checkDevelopmentEnding()
    local run, profile = fresh()
    prepareStableHousehold(run)
    for year = 1, 10 do
        resolvePending(run, profile)
        local ok, message = Simulation.AdvanceYear(run, profile)
        assert(ok, message)
        if year == 1 then
            local successor = assert(livingAdult(run, run.leaderId), "正常经营后缺少可交接的成年族人。")
            ok, message = Simulation.AppointLeader(run, successor.id, "终章合同交接")
            assert(ok, message)
        end
    end
    assert(Simulation.IsEndingReady(run, "peaceful") and run.ending == nil, "发展终章资格没有与继续经营分离。")
    local member = assert(livingAdult(run), "发展终章后缺少可继续安排的人。")
    local ok, message = Simulation.SetJob(run, member.id, "home")
    assert(ok, message)
    assert(run.ending == nil, "达成发展终章资格时提前结束了本局。")
    local pending = { instanceId = "t08-development-pending", type = "legacy_pending", title = "终章前家事", status = "pending" }
    table.insert(run.events, pending)
    ok, message = Simulation.ClaimEnding(run, "peaceful", profile)
    assert(ok, message)
    assert(run.ending.id == "peaceful" and not run.ending.automatic and #profile.endingRecords == 1 and run.ending.factId,
        "发展终章没有同时写入本局、Profile 与终章事实。")
    assert(pending.status == "cancelled" and pending.closedByEndingId == "peaceful", "确认落笔没有关闭待决事件。")
    return { years = run.yearIndex, ending = run.ending.id, profileRecords = #profile.endingRecords }
end

local function forceOrdinaryYear(run)
    for _, member in ipairs(run.members) do
        member.age, member.health, member.jobId, member.birthPlan = 30, 100, "play", false
    end
    run.land = 0
end

local function checkResourceBoundary()
    local run, profile = fresh()
    forceOrdinaryYear(run)
    run.money, run.grain = 0, 40
    assert(not Simulation.IsFamilyCollapsed(run), "存粮尚在时被判定为家道散尽。")
    assert(Simulation.AdvanceYear(run, profile), "钱粮仍有一项时无法推进年度。")
    assert(run.grain > 0 and run.ending == nil and not run.lastLedger.resourcesExhausted,
        "钱粮仍有一项时错误写入家道终局。")
end

local function checkBatchJobArrangement()
    local run = fresh()
    local adults, child = {}, nil
    for _, member in ipairs(run.members) do
        if State.IsAdult(member) and #adults < 2 then
            member.jobId = "play"
            table.insert(adults, member)
        elseif not State.IsAdult(member) and not child then
            child = member
            child.jobId = "play"
        end
    end
    assert(#adults == 2 and child, "批量安排验收缺少两位成年人和一位未成年人。")
    local ids = { adults[1].id, adults[2].id, child.id }
    local plan, forecast = Simulation.PreviewBatchJob(run, ids, "farm")
    assert(plan and #plan.targets == 2 and #plan.blocked == 1 and forecast and type(forecast.netMoney) == "number",
        "批量安排预览没有区分可安排人与条件保留人。")
    local facts = #run.facts
    local ok, message = Simulation.SetJobs(run, ids, "farm")
    assert(ok, message)
    assert(adults[1].jobId == "farm" and adults[2].jobId == "farm" and child.jobId == "play" and #run.facts == facts + 2,
        "批量安排没有分别写入成年人，或改写了条件不符的族人。")
    local repeatPlan = assert(Simulation.PreviewBatchJob(run, ids, "farm"))
    assert(#repeatPlan.targets == 0 and #repeatPlan.unchanged == 2 and #repeatPlan.blocked == 1,
        "已有安排与条件保留状态没有被正确识别。")
    return { arranged = #plan.targets, blocked = #plan.blocked, unchanged = #repeatPlan.unchanged }
end

local function createNaturalEnding()
    local run, profile, draft = fresh()
    for _, member in ipairs(run.members) do
        member.age, member.health, member.jobId, member.birthPlan = 150, 0, "rest", false
    end
    run.money, run.grain, run.land = 200, 100, 0
    run.yearIndex = 4
    assert(Simulation.AdvanceYear(run, profile), "全员离世年度无法结算。")
    local record = assert(run.ending, "全员离世后没有写入家谱落笔。")
    local archived = assert(profile.endingRecords[1], "全员离世终局没有写入 Profile 档案。")
    local fact = assert(factById(run, record.factId), "全员离世终局没有写入家史事实。")
    assert(record.id == "last" and record.automatic and record.automaticTrigger == "living_members_exhausted"
        and archived.automaticTrigger == "living_members_exhausted" and fact.automaticTrigger == "living_members_exhausted"
        and record.evidence[1].current == 0, "家谱落笔的状态、条件快照与终章事实不一致。")
    assert(#record.closingEventIds == 1 and run.events[#run.events].status == "cancelled"
        and run.events[#run.events].closedByEndingId == "last", "家谱落笔没有关闭本年待决家事。")
    return run, profile, draft, { ending = record.id, automaticTrigger = record.automaticTrigger, closedEvents = #record.closingEventIds }
end

local function checkNaturalEnding()
    local _, _, _, evidence = createNaturalEnding()
    return evidence
end

local function qualifiedProgressRun()
    local run = fresh()
    run.yearIndex, run.money, run.grain, run.reputation, run.workshop = 20, 500, 100, 100, true
    run.metrics.stable, run.metrics.foodYears, run.metrics.aid = 20, 20, 5
    run.metrics.migrations, run.metrics.lastMove = 1, 1
    run.flags.promiseKept, run.flags.rulerRestored, run.flags.bookRestored = true, true, true
    run.leaderTerms = { { memberId = run.leaderId, startYear = 0, endYear = 2, effective = true, factId = "progress-handover" } }
    local first, second = run.members[1], run.members[3]
    first.hadHomeAfterGuard = true
    for _, member in ipairs(run.members) do member.jobYears = {} end
    first.jobYears = { teach = 3, trade = 3, craft = 6, doctor = 6 }
    second.jobYears = { teach = 3, trade = 3, craft = 6, doctor = 6 }
    assert(State.Generation(run.members, first.id) ~= State.Generation(run.members, second.id), "终章进度夹具缺少两代人物。")
    return run
end

local function checkAllDevelopmentProgress()
    local breakOne = {
        peaceful = function(run) run.metrics.stable = 4 end,
        scholar = function(run) run.money = 199 end,
        merchant = function(run) run.money = 299 end,
        craft = function(run) run.workshop = false end,
        medical = function(run) run.members[1].jobYears.doctor = 5 end,
        grain = function(run) run.metrics.foodYears = 9 end,
        community = function(run) run.metrics.aid = 2 end,
        migration = function(run) run.metrics.lastMove = 13 end,
        ["return"] = function(run) run.members[1].hadHomeAfterGuard = false end,
        promise = function(run) run.flags.promiseKept = false end,
        ruler = function(run) run.flags.rulerRestored = false end,
        reunion = function(run) run.flags.bookRestored = false end,
    }
    local checked = 0
    for _, ending in ipairs(Data.Endings) do
        if not ending.automatic then
            local run = qualifiedProgressRun()
            local progress = Simulation.EndingProgress(run, ending.id)
            assert(#progress > 0 and Simulation.IsEndingReady(run, ending.id), "发展终章缺少可达成的正式条件：" .. ending.id)
            for _, item in ipairs(progress) do
                assert(type(item[1]) == "string" and type(item[2]) == "number" and type(item[3]) == "number"
                    and type(item[4]) == "string" and type(item[5]) == "table" and type(item[5].source) == "string",
                    "发展终章条件行缺少当前量、目标量、类型或来源：" .. ending.id)
            end
            breakOne[ending.id](run)
            local missing = 0
            for _, item in ipairs(Simulation.EndingProgress(run, ending.id)) do
                if not Simulation.IsProgressMet(item) then missing = missing + 1 end
            end
            assert(missing == 1 and not Simulation.IsEndingReady(run, ending.id), "发展终章差一项时仍可领取：" .. ending.id)
            checked = checked + 1
        end
    end
    assert(checked == 12, "发展终章循环覆盖数量错误。")
    return checked
end

local function checkCollapseAndReadOnly()
    local run, profile, draft = fresh()
    forceOrdinaryYear(run)
    run.money, run.grain = 0, 0
    assert(Simulation.AdvanceYear(run, profile), "钱粮归零年度无法结算。")
    local record = assert(run.ending, "钱粮同归零后没有写入终局。")
    local archived = assert(profile.endingRecords[1], "终局没有写入 Profile 档案。")
    local fact = assert(factById(run, record.factId), "终局没有写入可回顾事实。")
    assert(record.id == "collapse" and record.automatic and record.automaticTrigger == "resources_exhausted"
        and archived.automaticTrigger == "resources_exhausted" and fact.automaticTrigger == "resources_exhausted"
        and run.lastLedger.resourcesExhausted and #record.evidence == 2 and record.evidence[1].current == 0 and record.evidence[2].current == 0,
        "家道散尽的状态、条件快照与终章事实不一致。")
    local member = run.members[1]
    local relic = run.relicInstances[1]
    local writes = {
        function() return Simulation.SetJob(run, member.id, "farm") end,
        function() return Simulation.SetBirthPlan(run, member.id, false) end,
        function() return Simulation.TakeExam(run, member.id) end,
        function() return Simulation.AppointLeader(run, member.id, "终局后任命") end,
        function() return Simulation.Marry(run, member.id) end,
        function() return Simulation.Adopt(run, member.id) end,
        function() return Simulation.MoveFamily(run, "port") end,
        function() return Simulation.BuyAsset(run, "land") end,
        function() return Simulation.BuyGrain(run, 1) end,
        function() return Simulation.SellRelic(run, relic.instanceId) end,
        function() return Simulation.TransferRelic(run, relic.instanceId, member.id) end,
        function() return Simulation.AssignRelicExecutor(run, relic.instanceId, member.id) end,
        function() return Simulation.InviteBranch(run, relic.instanceId) end,
        function() return Simulation.PauseRelicInvestigation(run, relic.instanceId) end,
        function() return Simulation.ResumeRelicInvestigation(run, relic.instanceId) end,
        function() return Simulation.StartRelicInvestigation(run, relic.instanceId, "fast", member.id) end,
        function() return Simulation.StartJadeSearch(run, relic.instanceId, member.id) end,
        function() return Simulation.ResumeRelicStory(run, relic.instanceId) end,
        function() return Simulation.ResolveEvent(run, "终局后家事", "defer", profile) end,
        function() return Simulation.ResolveLeaderEvent(run, "终局后家事", member.id) end,
        function() return Simulation.AidCommunity(run) end,
        function() return Simulation.AdvanceYear(run, profile) end,
        function() return Simulation.ClaimEnding(run, "peaceful", profile) end,
    }
    for _, write in ipairs(writes) do
        local beforeRun, beforeProfile = State.Copy(run), State.Copy(profile)
        local ok = write()
        assert(not ok and same(run, beforeRun) and same(profile, beforeProfile), "终局后写入口改写了状态。")
    end

    local app = App.New()
    app.profile, app.draft, app.run, app.screen, app.gameTab = profile, draft, run, "game", "family"
    app:Render()
    assert(contains(UI.root, "本局已落笔 · 家道散尽") and contains(UI.root, "年度结算后公库与存粮同时归零时自动写入"),
        "家族页没有绑定家道终局状态。")
    app.gameTab, app.historySection = "history", "endings"
    app:Render()
    assert(contains(UI.root, "本局终章 · 家道散尽") and contains(UI.root, "十四条终章"), "家史没有回顾终局快照。")

    assert(State.Save(profile, draft, run), "终局存档写入失败。")
    return { ending = record.id, automaticTrigger = record.automaticTrigger, writes = #writes, facts = #run.facts }
end

local function run()
    assert(#Data.Endings == 14 and Data.Ending("last").automaticTrigger == "living_members_exhausted"
        and Data.Ending("collapse").automaticTrigger == "resources_exhausted", "十四条终章定义或自动触发来源缺失。")
    local development = checkDevelopmentEnding()
    local developmentProgress = checkAllDevelopmentProgress()
    checkResourceBoundary()
    local batchArrangement = checkBatchJobArrangement()
    local natural = checkNaturalEnding()
    local collapse = checkCollapseAndReadOnly()
    return { development = development, developmentProgress = developmentProgress, batchArrangement = batchArrangement, natural = natural, collapse = collapse, moneyOrGrainRemains = true, uiHistory = true }
end

local function restart()
    local restored = assert(State.Load(), "终局存档重启后缺失。")
    local record = assert(restored.run.ending, "重启后终局记录丢失。")
    assert(record.id == "collapse" and record.automaticTrigger == "resources_exhausted"
        and restored.profile.endingRecords[1].factId == record.factId, "重启后 Run、Profile 与终章事实引用不一致。")
    return { ending = record.id, trigger = record.automaticTrigger, profileRecords = #restored.profile.endingRecords }
end

local function saveNatural()
    local run, profile, draft, evidence = createNaturalEnding()
    assert(State.Save(profile, draft, run), "家谱落笔存档写入失败。")
    return evidence
end

local function naturalRestart()
    local restored = assert(State.Load(), "家谱落笔存档重启后缺失。")
    local record = assert(restored.run.ending, "重启后家谱落笔记录丢失。")
    assert(record.id == "last" and record.automaticTrigger == "living_members_exhausted"
        and restored.profile.endingRecords[1].factId == record.factId and #record.closingEventIds == 1,
        "重启后家谱落笔的 Run、Profile、事件关闭与事实引用不一致。")
    return { ending = record.id, trigger = record.automaticTrigger, closedEvents = #record.closingEventIds }
end

return { run = run, restart = restart, batch = checkBatchJobArrangement, saveNatural = saveNatural, naturalRestart = naturalRestart }
