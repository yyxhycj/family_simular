---@diagnostic disable: undefined-global
local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Opening = require "Jiaye.Opening"

local function Same(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not Same(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function Adults(members)
    local adults = {}
    for _, member in ipairs(members) do if member.age >= 18 then table.insert(adults, member) end end
    return adults
end

local function SelectedRelicCount(draft)
    return #(draft.selectedRelicFormIds or draft.selectedRelicIds or {})
end

local function GeneratedDraft(profile, predicate)
    for seed = 1, 4096 do
        local draft = Opening.Generate(profile, seed, "mortal")
        if draft and predicate(draft) then return draft end
    end
    error("未找到满足真实开局条件的家庭。")
end

local function NewRun(profile, predicate)
    local draft = GeneratedDraft(profile, predicate)
    local run, issues = State.NewRun(draft, profile)
    assert(run, table.concat(issues or {}, "；"))
    return run, draft
end

local function LivingAdult(run)
    for _, member in ipairs(run.members) do if member.alive and member.age >= 18 then return member end end
    return nil
end

local function LivingAdultExcept(run, memberId)
    for _, member in ipairs(run.members) do
        if member.alive and member.age >= 18 and member.id ~= memberId then return member end
    end
    return nil
end

local function ResolvePending(run, profile)
    for _ = 1, 128 do
        local pending = Simulation.PendingEvents(run)
        if #pending == 0 then return end
        local event = pending[1]
        local ok, message
        if event.type == "leader" then
            local adult = LivingAdult(run)
            assert(adult, "继任事件出现时没有在世成年人。")
            ok, message = Simulation.ResolveLeaderEvent(run, event.instanceId, adult.id)
        else
            ok, message = Simulation.ResolveEvent(run, event.instanceId, "defer", profile)
        end
        assert(ok, message)
    end
    error("待决事件未在限定步数内结清。")
end

local function DisableBirths(run)
    for _, member in ipairs(run.members) do
        if member.alive and member.age >= 18 then
            local canPlan = State.CanPlanBirth(member, run.members)
            if canPlan then
                local ok, message = Simulation.SetBirthPlan(run, member.id, false)
                assert(ok, message)
            end
        end
    end
end

local function CheckDevelopmentEnding(lines)
    local profile = State.NewProfile()
    local run = NewRun(profile, function(draft)
        local adults = Adults(draft.members)
        return #adults >= 2 and adults[1].age <= 44 and adults[2].age <= 44
            and draft.money >= 60 and draft.grain >= 12 and SelectedRelicCount(draft) == 0
    end)
    local adults = Adults(run.members)
    for _, member in ipairs(adults) do
        local ok, message = Simulation.SetJob(run, member.id, "farm")
        assert(ok, message)
    end
    DisableBirths(run)
    local failed = Simulation.ClaimEnding(run, "peaceful", profile)
    assert(not failed and run.ending == nil and #profile.endingRecords == 0, "未达成终章被写入。")

    for year = 1, 10 do
        ResolvePending(run, profile)
        local ok, message = Simulation.AdvanceYear(run, profile)
        assert(ok, message)
        if year == 1 then
            local successor = LivingAdultExcept(run, run.leaderId)
            assert(successor, "真实家庭未保留可交接的成年人。")
            ok, message = Simulation.AppointLeader(run, successor.id, "验收交接")
            assert(ok, message)
        end
    end
    assert(Simulation.IsEndingReady(run, "peaceful"), "真实经营十年后未获得安稳终章资格。")
    assert(run.ending == nil, "资格达成时提前落笔。")
    local ok, message = Simulation.ClaimEnding(run, "peaceful", profile)
    assert(ok, message)
    assert(run.ending.id == "peaceful" and not run.ending.automatic, "发展终章记录缺失。")
    assert(#run.ending.evidence == 3 and #profile.endingRecords == 1 and run.ending.factId, "发展终章快照或档案缺失。")
    assert(#Simulation.PendingEvents(run) == 0, "发展终章后仍保留待决事件。")
    table.insert(lines, "发展终章：资格继续经营，确认后写入条件快照与档案")
end

local function CheckNaturalEnding(lines)
    local profile = State.NewProfile()
    local run, draft = NewRun(profile, function(draft)
        return #Adults(draft.members) >= 2 and #draft.selectedRelicIds == 0
    end)
    DisableBirths(run)
    for _ = 1, 128 do
        ResolvePending(run, profile)
        local ok, message = Simulation.AdvanceYear(run, profile)
        assert(ok, message)
        if run.ending then break end
    end
    assert(run.ending and run.ending.id == "last" and run.ending.automatic, "全员离世后未写入自然终局。")
    assert(#profile.endingRecords == 1 and run.ending.evidence[1].current == 0, "自然终局档案或在世人数快照错误。")
    assert(#Simulation.PendingEvents(run) == 0, "自然终局后仍保留待决事件。")
    local restored, importMessage = State.Import(cjson.encode({ profile = profile, draft = draft, run = run }))
    assert(restored and importMessage and restored.run.ending.id == "last" and restored.profile.endingRecords[1].factId == run.ending.factId, "终章存档编码或读取后的状态不一致。")

    local actions = {
        function() return Simulation.SetJob(run, "missing", "farm") end,
        function() return Simulation.SetBirthPlan(run, "missing", false) end,
        function() return Simulation.TakeExam(run, "missing") end,
        function() return Simulation.AppointLeader(run, "missing", "验收") end,
        function() return Simulation.Marry(run, "missing") end,
        function() return Simulation.Adopt(run, "missing") end,
        function() return Simulation.MoveFamily(run, "port") end,
        function() return Simulation.BuyAsset(run, "land") end,
        function() return Simulation.SellRelic(run, "missing") end,
        function() return Simulation.TransferRelic(run, "missing", "missing") end,
        function() return Simulation.AssignRelicExecutor(run, "missing", "missing") end,
        function() return Simulation.InviteBranch(run, "missing") end,
        function() return Simulation.PauseRelicInvestigation(run, "missing") end,
        function() return Simulation.ResumeRelicInvestigation(run, "missing") end,
        function() return Simulation.StartRelicInvestigation(run, "missing", "fast") end,
        function() return Simulation.StartJadeSearch(run, "missing") end,
        function() return Simulation.ResumeRelicStory(run, "missing") end,
        function() return Simulation.ResolveEvent(run, "missing", "defer", profile) end,
        function() return Simulation.ResolveLeaderEvent(run, "missing", "missing") end,
        function() return Simulation.AidCommunity(run) end,
        function() return Simulation.AdvanceYear(run, profile) end,
        function() return Simulation.ClaimEnding(run, "peaceful", profile) end,
    }
    for _, action in ipairs(actions) do
        local beforeRun, beforeProfile = State.Copy(run), State.Copy(profile)
        local ok = action()
        assert(not ok and Same(beforeRun, run) and Same(beforeProfile, profile), "终局后写操作改变了记录。")
    end
    table.insert(lines, "自动终局：全员离世、档案与存档编码一致、全部运行期写操作保持只读")
end

local function CheckResourceCollapse(lines)
    local profile = State.NewProfile()
    local run, draft = NewRun(profile, function(draft) return #Adults(draft.members) >= 1 and SelectedRelicCount(draft) == 0 end)
    for _, member in ipairs(run.members) do
        member.age, member.health, member.jobId, member.birthPlan = 30, 100, "play", false
    end
    run.money, run.grain, run.land = 0, 0, 0
    assert(Simulation.AdvanceYear(run, profile))
    assert(run.ending and run.ending.id == "collapse" and run.ending.automatic, "钱粮俱尽后未自动写入家道终局。")
    assert(run.lastLedger.resourcesExhausted and #run.ending.evidence == 2 and run.ending.evidence[1].current == 0 and run.ending.evidence[2].current == 0,
        "家道终局没有保留钱粮归零证据。")
    assert(#profile.endingRecords == 1 and #Simulation.PendingEvents(run) == 0 and #Adults(run.members) >= 1, "家道终局档案、事件关闭或人物保留错误。")
    local restored, importMessage = State.Import(cjson.encode({ profile = profile, draft = draft, run = run }))
    assert(restored and importMessage and restored.run.ending.id == "collapse" and restored.profile.endingRecords[1].factId == run.ending.factId,
        "家道终局存档编码或读取后的状态不一致。")
    local before = State.Copy(run)
    assert(not Simulation.SetJob(run, run.members[1].id, "farm") and Same(before, run), "家道终局后仍可改写运行家谱。")
    table.insert(lines, "家道终局：钱粮同归零、账本与终章证据一致、人物经历保留且运行期只读")
end

local function CheckBoundaryRules(lines)
    local profile = State.NewProfile()
    local run = NewRun(profile, function(draft) return #Adults(draft.members) >= 2 end)
    local first, second = run.leaderId, Adults(run.members)[2].id
    local ok, message = Simulation.AppointLeader(run, second, "同年验收")
    assert(ok, message)
    assert(Simulation.EndingProgress(run, "peaceful")[3][2] == 0, "同年交接被计入真实传承。")

    local marriageProfile = State.NewProfile()
    local marriageRun = NewRun(marriageProfile, function(draft)
        for _, member in ipairs(draft.members) do
            if member.age >= 18 and not member.spouseId then return draft.money >= 12 end
        end
        return false
    end)
    local guardian = nil
    for _, member in ipairs(marriageRun.members) do if member.age >= 18 and not member.spouseId then guardian = member; break end end
    assert(guardian, "真实家庭未提供可婚配成年人。")
    ok, message = Simulation.Marry(marriageRun, guardian.id)
    assert(ok, message)
    local spouse = State.FindMember(marriageRun.members, guardian.spouseId)
    assert(spouse and spouse.generation == guardian.generation, "婚入成员代际错误。")

    local earlyDraft = State.NewDraft()
    earlyDraft.calendar = Data.Period(earlyDraft.periodId).years[1]
    local lateDraft = State.Copy(earlyDraft)
    lateDraft.calendar = Data.Period(lateDraft.periodId).years[#Data.Period(lateDraft.periodId).years]
    local earlyRun = assert(State.NewRun(earlyDraft, State.NewProfile()))
    local lateRun = assert(State.NewRun(lateDraft, State.NewProfile()))
    assert(Simulation.EndingProgress(earlyRun, "peaceful")[1][2] == 0 and Simulation.EndingProgress(lateRun, "peaceful")[1][2] == 0, "开局年份影响了实际经营年数。")
    assert(first ~= second, "同年交接缺少不同继任人。")
    table.insert(lines, "边界：同年交接、同代婚入与开局年份均不伪造传承")
end

local function CheckActionEligibility(lines)
    local profile = State.NewProfile()
    local run = assert(State.NewRun(State.NewDraft(), profile))
    local paired = run.members[1]
    local pairedBefore = State.Copy(run)
    local ok = Simulation.Marry(run, paired.id)
    assert(not ok and Same(pairedBefore, run), "已有配偶仍可再次婚配。")

    local unmarried = run.members[3]
    assert(not State.CanPlanBirth(unmarried, run.members), "无配偶族人仍可安排添丁计划。")
    assert(Simulation.Marry(run, unmarried.id), "在世成年未婚族人无法婚配。")
    local marriedBefore = State.Copy(run)
    ok = Simulation.Marry(run, unmarried.id)
    assert(not ok and Same(marriedBefore, run), "完成婚配后仍可重复婚配。")

    local firstCount = #run.members
    assert(Simulation.Adopt(run, paired.id), "第一次收养失败。")
    assert(Simulation.Adopt(run, paired.id), "第二次收养失败。")
    local firstChild, secondChild = run.members[firstCount + 1], run.members[firstCount + 2]
    assert(firstChild.name ~= secondChild.name, "多次收养生成了同名孩子。")

    paired.examPassed = true
    local examBefore = State.Copy(run)
    ok = Simulation.TakeExam(run, paired.id)
    assert(not ok and Same(examBefore, run), "已取得任职资格后仍可重复应试。")

    local relic = run.relicInstances[1]
    relic.status = "investigating"
    local relicBefore = State.Copy(run)
    ok = Simulation.TransferRelic(run, relic.instanceId, paired.id)
    assert(not ok and Same(relicBefore, run), "调查中的信物仍可更换保管人。")

    local branchRun = assert(State.NewRun(State.NewDraft(), State.NewProfile()))
    local branchRelic = branchRun.relicInstances[1]
    branchRelic.definitionId = "newbook"
    branchRun.members[3].name = branchRun.openingSnapshot.family .. "怀远"
    assert(Simulation.InviteBranch(branchRun, branchRelic.instanceId), "旁支归家失败。")
    assert(branchRun.members[#branchRun.members].name ~= branchRun.openingSnapshot.family .. "怀远", "旁支归家生成了同名族人。")
    table.insert(lines, "行动资格：婚配、添丁、收养命名、应试与信物保管均按当前家谱状态约束")
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    assert(#Data.Endings == 14 and Data.Ending("last").automatic and Data.Ending("collapse").automatic, "终章登记不完整。")
    local lines = { "T08 真实引擎验收通过" }
    CheckDevelopmentEnding(lines)
    CheckNaturalEnding(lines)
    CheckResourceCollapse(lines)
    CheckBoundaryRules(lines)
    CheckActionEligibility(lines)
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", alignItems = "center", children = {
        UI.Panel { width = 420, maxWidth = "100%", gap = 12, padding = 16, children = (function()
            local children = { UI.Label { text = lines[1], fontSize = 24 } }
            for index = 2, #lines do table.insert(children, UI.Label { text = "• " .. lines[index], whiteSpace = "normal" }) end
            return children
        end)() },
    } })
    print("T08_QA_PASS " .. table.concat(lines, " | "))
end

function Stop()
    UI.Shutdown()
end
