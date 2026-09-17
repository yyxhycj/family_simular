local State = require "Jiaye.State"
local Sim = require "Jiaye.Simulation"
local App = require "Jiaye.App"
local cases = {}
local function same(a, b) return cjson.encode(a) == cjson.encode(b) end
local function fresh()
    local profile, draft = State.NewProfile(), State.NewDraft()
    return assert(State.NewRun(draft, profile)), profile, draft
end
local function find(root, text)
    if root.text == text then return root end
    for _, child in ipairs(root.children or {}) do local found = find(child, text); if found then return found end end
end
local function click(root, text)
    local button = assert(find(root, text), "missing UI binding: " .. text)
    assert(not button.disabled, "disabled UI binding: " .. text); button.onClick(button)
    return button
end
local function loadedMatches(app)
    local value = assert(State.Load())
    assert(same(value.profile, app.profile) and same(value.draft, app.draft) and same(value.run, app.run), "UI model differs from stored payload")
    return value
end
local function resume()
    local app = App.New(); app:Load(); loadedMatches(app); return app
end

cases.history = {
    run = function()
        local run, profile, draft = fresh()
        for i = 1, 151 do State.AddLog(run, "entry-" .. i) end
        assert(#run.logs == 151 and run.logs[151].text == "entry-1")
        assert(State.Save(profile, draft, run))
        local app = resume(); local before = State.Copy(app.run)
        app.gameTab = "history"; app:Render()
        assert(find(UI.root, "大晟历 72 年 · entry-151") and not find(UI.root, "大晟历 72 年 · entry-1"))
        click(UI.root, "最早")
        assert(app.historyPage == 8 and find(UI.root, "大晟历 72 年 · entry-1"))
        assert(find(UI.root, "下一页").disabled)
        click(UI.root, "上一页"); click(UI.root, "下一页"); click(UI.root, "最新")
        assert(app.historyPage == 1 and same(before, app.run)); loadedMatches(app)
        return { count = #run.logs, oldest = run.logs[151], pages = 8, pageSize = 20, readOnly = true }
    end,
    restart = function()
        local app = resume(); app.gameTab = "history"; app:Render(); click(UI.root, "最早")
        assert(find(UI.root, "大晟历 72 年 · entry-1")); assert(#app.run.logs == 151)
        return { oldestVisible = true, count = #app.run.logs, rng = app.run.rngState }
    end,
}

local function succession()
    local run, profile, draft = fresh()
    run.members = { run.members[1], run.members[2] }; run.members[1].age = 89; run.members[2].age = 30
    for index = #run.facts, 1, -1 do
        local keep = true
        for _, memberId in ipairs(run.facts[index].memberIds or {}) do if memberId > 2 then keep = false end end
        if not keep then table.remove(run.facts, index) end
    end
    for _, person in ipairs(run.members) do person.spouseId = nil; person.birthPlan = false end
    run.rngState = 1
    assert(Sim.AdvanceYear(run, profile)); assert(not run.members[1].alive and run.members[2].alive)
    local event = Sim.PendingEvents(run)[1]; assert(event.type == "leader")
    -- Reward-bearing succession fixture; the death and event above use the actual annual command.
    table.insert(run.relicInstances, { instanceId = "test-book", definitionId = "newbook", status = "held", custodianId = 2 })
    return run, profile, draft, event
end
cases.succession = {
    run = function()
        local evidence = {}
        for _, entrance in ipairs({ "event", "member" }) do
            local run, profile, draft, event = succession()
            local before = State.Copy(run)
            assert(not Sim.AppointLeader(run, 1) and not Sim.AppointLeader(run, 999))
            run.members[2].age = 17; assert(not Sim.ResolveLeaderEvent(run, event.instanceId, 2)); run.members[2].age = 31
            assert(same(run, before), "invalid appointment mutated state")
            assert(State.Save(profile, draft, run)); local app = resume()
            if entrance == "event" then
                click(app:BuildPendingEvent(app.run.events[1]), "任命 许青")
                click(UI.modal, "确认任命")
            else
                app:OpenRunMember(2); click(UI.modal, "任命为族长")
                click(UI.modal, "确认交接")
            end
            run = app.run
            assert(run.leaderId == 2 and #run.leaderTerms == 2 and run.leaderTerms[1].endYear == 1)
            assert(#Sim.PendingEvents(run) == 0 and run.events[1].memberId == 2)
            assert(run.reputation == before.reputation + 3 and #run.logs == #before.logs + 2)
            assert(run.money == before.money and run.grain == before.grain and run.rngState == before.rngState)
            assert(find(app:BuildAnnualFooter(), "推进这一年")); loadedMatches(app)
            local resolved = State.Copy(run)
            assert(not Sim.AppointLeader(run, 2) and not Sim.ResolveLeaderEvent(run, event.instanceId, 2))
            assert(same(run, resolved), "duplicate appointment rewarded twice")
            -- Old broken save: target already appointed, event accidentally still pending.
            run.events[1].status = "pending"; run.events[1].memberId = nil; run.events[1].resolvedYear = nil
            assert(Sim.ResolveLeaderEvent(run, event.instanceId, 2)); assert(same(run, resolved))
            assert(app:Save()); loadedMatches(app)
            evidence[entrance] = { leader = run.leaderId, terms = run.leaderTerms, event = run.events[1], reputation = run.reputation }
        end
        return evidence
    end,
    restart = function()
        local app = resume(); assert(app.run.leaderId == 2 and #Sim.PendingEvents(app.run) == 0)
        click(app:BuildAnnualFooter(), "推进这一年"); assert(app.run.yearIndex == 2); loadedMatches(app)
        return { resumedYear = app.run.yearIndex, leader = app.run.leaderId }
    end,
}

cases.collection = {
    run = function()
        local run, profile, draft = fresh()
        assert(Sim.StartRelicInvestigation(run, "relic-1", "fast")); assert(Sim.AdvanceYear(run, profile))
        assert(Sim.ResolveEvent(run, Sim.PendingEvents(run)[1].instanceId, "restore", profile))
        assert(profile.unlockedRelicIds.plan)
        -- 已有局外终章记录的存档夹具，仅验证保留，不作为终章达成证据。
        profile.endingRecords = { { id = "peaceful", title = "旧局存档夹具", year = 70 } }
        assert(State.Save(profile, draft, run)); local app = App.New()
        assert(app.profile.unlockedRelicIds.plan and same(app.run, run))
        local saved = State.Copy(assert(State.Load()))
        app:PrepareNewRun(); app.draft.family = "欧阳"; app.openingPage = "final"; app:Render()
        app:StartRun(); local cancel = UI.modal; click(cancel, "取消")
        assert(same(assert(State.Load()), saved) and same(app.run, run))
        app:CancelNewRun(); assert(same(app.draft, draft) and app.screen == "game")
        app:PrepareNewRun(); app.draft = State.NewDraft() -- 明确使用冻结97点夹具，不依赖新的随机默认家庭。
        app:ToggleRelic("plan"); app.draft.money = 0
        assert(State.TotalPoints(app.draft) == 99)
        local displayed = State.Copy(app.draft)
        app:StartRun(); local confirm = click(UI.modal, "确认开始")
        local created = State.Copy(app.run); confirm.onClick(confirm)
        assert(same(created, app.run) and same(displayed, app.run.openingSnapshot))
        assert(same(app.profile, profile) and app.profile.unlockedRelicIds.plan and #app.run.relicInstances == 2)
        assert(app.run.yearIndex == 0 and app.screen == "game"); loadedMatches(app)
        return { unlocked = app.profile.unlockedRelicIds, total = State.TotalPoints(app.draft), snapshot = app.run.openingSnapshot, cancelledUnchanged = true }
    end,
    restart = function()
        local app = resume(); assert(app.profile.unlockedRelicIds.plan and #app.run.relicInstances == 2)
        assert(#app.profile.endingRecords == 1 and app.profile.endingRecords[1].title == "旧局存档夹具")
        assert(State.TotalPoints(app.draft) == 99 and app.run.yearIndex == 0)
        return { unlocked = app.profile.unlockedRelicIds, total = State.TotalPoints(app.draft) }
    end,
}

cases.failed_new_run = {
    run = function()
        local first = App.New(); first:PrepareNewRun(); fault.mode = "partial"; first:StartRun(); fault.mode = ""
        assert(first.run == nil and first.screen == "opening"); first:StartRun()
        assert(first.run and not first.startConfirmationOpen); loadedMatches(first)
        local run, profile, draft = fresh(); assert(State.Save(profile, draft, run))
        local app = resume(); local saved = State.Copy(assert(State.Load())); local modes = {}
        app:PrepareNewRun(); app.draft.family = "候选"; app.openingPage = "final"
        for _, mode in ipairs({ "open", "partial", "zero", "corrupt", "exception" }) do
            fault.mode = mode; app:StartRun(); click(UI.modal, "确认开始"); fault.mode = ""
            assert(same(app.run, run) and app.draft.family == "候选" and app.screen == "opening")
            assert(same(assert(State.Load()), saved) and notices[#notices].variant == "error")
            modes[mode] = { oldRunPreserved = true, candidatePreserved = true, notification = notices[#notices] }
        end
        app.draft.money = 999; app:StartRun(); assert(not app.startConfirmationOpen)
        assert(same(assert(State.Load()), saved)); app:CancelNewRun(); assert(same(app.draft, draft))
        return modes
    end,
    restart = function()
        local app = App.New(); assert(app.run.yearIndex == 0 and app.draft.family == "林")
        assert(app.saveMessage ~= ""); app:Load(); loadedMatches(app)
        return { oldFamily = app.draft.family, recoveryMessage = app.saveMessage }
    end,
}

cases.failed_action = {
    run = function()
        local run, profile, draft = fresh(); assert(State.Save(profile, draft, run))
        local app = resume(); fault.mode = "partial"
        app:RunAction(function() return Sim.AidCommunity(app.run) end)
        assert(app.unsaved and app.run.money == 65 and assert(State.Load()).run.money == 80)
        assert(notices[#notices].variant == "error" and find(UI.root, "重试保存"))
        local pending = State.Copy(app.run)
        app:RunAction(function() error("blocked action executed") end); app:Load(); app:PrepareNewRun()
        assert(same(pending, app.run) and app.screen == "game")
        app:Export(); assert(notices[#notices].variant == "error")
        fault.mode = ""; app:Export(); assert(notices[#notices].variant == "success")
        local file = File("jiaye_export.json", FILE_READ)
        local backup = State.Import(file:ReadString()); file:Close()
        assert(same(backup.run, app.run))
        click(UI.root, "重试保存"); assert(not app.unsaved and app.saveMessage == ""); loadedMatches(app)
        return { money = app.run.money, aidCount = app.run.metrics.aid, logCount = #app.run.logs, exportMatches = true }
    end,
    restart = function()
        local app = resume(); assert(app.run.money == 65 and app.run.metrics.aid == 1 and #app.run.logs == 1)
        return { money = app.run.money, aidCount = app.run.metrics.aid, logs = app.run.logs }
    end,
}

cases.recovery = {
    run = function()
        local run, profile, draft = fresh()
        -- Existing pre-T01 payload has no saveRevision and remains readable.
        disk_raw("jiaye_save.json", cjson.encode({ profile = profile, draft = draft, run = run }))
        assert(State.Load().saveRevision == 0)
        profile.unlockedRelicIds.plan = true; assert(State.Save(profile, draft, run))
        assert(State.Load().saveRevision == 1 and State.Load().profile.unlockedRelicIds.plan)
        disk_raw("jiaye_save.json", "{broken")
        local value, _, status = State.Load(); assert(status == "recovered" and value.profile.unlockedRelicIds.plan)
        local app = App.New(); assert(app.profile.unlockedRelicIds.plan and app.saveMessage ~= "")
        assert(app:Save()); assert(select(3, State.Load()) == "ok")
        local good = cjson.encode((assert(State.Load())))
        disk_raw("jiaye_save.json", "{broken"); disk_raw("jiaye_save.backup.json", "{broken")
        local blocked = App.New(); assert(blocked.storageBlocked and blocked.run == nil)
        blocked:PrepareNewRun(); blocked:StartRun(); assert(blocked.screen == "cover" and blocked.run == nil)
        assert(not blocked:Save() and State.Load() == nil)
        disk_raw("jiaye_save.json", good); blocked:Load(); assert(not blocked.storageBlocked)
        assert(blocked.profile.unlockedRelicIds.plan and blocked:Save()); loadedMatches(blocked)
        return { legacyLoaded = true, validSlotRecovered = true, bothBadBlocked = true, recoveredProfile = blocked.profile }
    end,
    restart = function()
        local app = resume(); assert(app.profile.unlockedRelicIds.plan and not app.storageBlocked)
        return { profile = app.profile, year = app.run.yearIndex }
    end,
}
return cases
