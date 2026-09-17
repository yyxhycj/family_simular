-- Direct public-module audit: no copied production functions, no RNG patching.
-- UI captures declarations/callbacks only. File is an isolated in-memory adapter.
local UI, notices, storage = {}, {}, { files = {}, failOpen = false, failWrite = false }
local function widget(kind, props)
    props = props or {}; props.kind = kind
    props.SetText = function(self, text) self.text = text end
    return props
end
for _, kind in ipairs({ "Panel", "Row", "Label", "Button", "TextField", "Stepper", "Toggle", "ScrollView", "Divider", "SafeAreaView" }) do
    UI[kind] = function(props) return widget(kind, props) end
end
UI.Box = function() return widget("Box") end
UI.SetRoot = function(root) UI.root = root end
UI.Toast = {
    GetGlobal = function() return { DismissAll = function() end } end,
    Show = function(message, props) table.insert(notices, { message = message, variant = props.variant }) end,
}
package.loaded["urhox-libs/UI"] = UI
FILE_READ, FILE_WRITE = 1, 2
File = function(path, mode)
    return {
        IsOpen = function() return not storage.failOpen end,
        WriteString = function(_, raw)
            if storage.failWrite then return 0 end
            storage.files[path] = raw; return #raw
        end,
        ReadString = function() return storage.files[path] end,
        Close = function() end,
    }
end
fileSystem = { FileExists = function(_, path) return storage.files[path] ~= nil end }

local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local App = require "Jiaye.App"
local Data = require "Jiaye.Data"
local results, fixtures = {}, {}
local function equal(a, b) return cjson.encode(a) == cjson.encode(b) end
local function check(id, title, ok, expected, actual)
    table.insert(results, { id = id, title = title, status = ok and "PASS" or "FAIL", expected = expected, actual = State.Copy(actual) })
end
local function fresh()
    local profile, draft = State.NewProfile(), State.NewDraft()
    local run, issues = State.NewRun(draft, profile)
    assert(run, table.concat(issues or {}, " "))
    return run, profile, draft
end
local function saveLoad(run, profile, draft)
    assert(State.Save(profile, draft, run))
    local loaded = assert(State.Load())
    assert(equal(loaded, { run = run, profile = profile, draft = draft }), "adapter round-trip changed payload")
    return loaded.run
end
local function find(root, predicate)
    if predicate(root) then return root end
    for _, child in ipairs(root.children or {}) do local found = find(child, predicate); if found then return found end end
end

local run, profile, draft = fresh()
-- runId is the only wall-clock field. Canonicalize fixture identity, not gameplay RNG.
run.runId = "t00-default"
local default = { profile = State.Copy(profile), draft = State.Copy(draft), run = State.Copy(run), points = State.PointGroups(draft), total = State.TotalPoints(draft) }

-- Baseline and real start validation; every variant goes through State.NewRun.
local gates = {}
for _, money in ipairs({ 80, 110, 120 }) do
    local candidate = State.Copy(draft); candidate.money = money
    local created = State.NewRun(candidate, profile)
    gates[#gates + 1] = { points = State.TotalPoints(candidate), accepted = created ~= nil }
end
local invalid = State.Copy(draft); invalid.members[4].parents = { 4 }
local locked = State.Copy(draft); locked.money = 0; locked.selectedRelicIds = { "plan" }
local multi = State.Copy(draft); multi.money = 0; multi.selectedRelicIds = { "book", "ruler", "letter" }; multi.originId = "plain"
check("G01", "97/100 可开、101/循环/锁定拒绝；三信物共享预算；草案原样入局",
    default.total == 97 and gates[1].accepted and gates[2].accepted and not gates[3].accepted
    and State.NewRun(invalid, profile) == nil and State.NewRun(locked, profile) == nil
    and State.NewRun(multi, profile) ~= nil and equal(run.openingSnapshot, draft),
    "97/100 accepted; 101/cycle/locked rejected; multi-select accepted; exact openingSnapshot",
    { gates = gates, multiPoints = State.TotalPoints(multi), cycleRejected = State.NewRun(invalid, profile) == nil, lockedRejected = State.NewRun(locked, profile) == nil })

local app = App.New(); app.screen = "opening"
local before = State.Copy(app.draft)
for _, page in ipairs({ "world", "people", "estate", "relics", "final" }) do app:SetOpeningPage(page); State.PageBudget(app.draft, page) end
app:StartRun()
local loaded = saveLoad(app.run, app.profile, app.draft)
local stable = equal(before, app.draft) and equal(before, loaded.openingSnapshot)
local successfulYear = Simulation.AdvanceYear(loaded, app.profile)
check("G02", "切页/计分/开始不重掷；存取往返；正常年度推进", stable and successfulYear and loaded.yearIndex == 1,
    "draft/RNG unchanged; stored opening matches; yearIndex=1", { stable = stable, year = loaded.yearIndex, money = loaded.money, grain = loaded.grain, stableYears = loaded.metrics.stable, foodYears = loaded.metrics.foodYears })

run, profile, draft = fresh()
for i = 1, 151 do State.AddLog(run, "entry-" .. i) end
run = saveLoad(run, profile, draft); fixtures.history151 = { profile = profile, draft = draft, run = State.Copy(run) }
check("P01", "151 条后首条日志可恢复", #run.logs == 151 and run.logs[#run.logs].text == "entry-1", "151 entries, oldest entry-1", { count = #run.logs, oldest = run.logs[#run.logs].text })

app = App.New(); app:RandomizePage("world"); app.draft.money = 180; app:UndoPage("world")
check("P02", "撤销世道不覆盖家底", app.draft.money == 180, "money=180", { money = app.draft.money })

run, profile, draft = fresh()
run.members = { run.members[1] }; local member = run.members[1]
member.age = 30; member.health = 60; member.jobId = "play"; member.spouseId = nil
run.land = 0; run.money = 0; run.grain = 0; run.metrics.stable = 4; run.metrics.foodYears = 7
assert(Simulation.AdvanceYear(run, profile)); run = saveLoad(run, profile, draft)
fixtures.starvation = { profile = profile, draft = draft, run = State.Copy(run) }
check("P03", "饥荒不算安稳", run.metrics.stable == 0, "stable=0", { stable = run.metrics.stable, health = run.members[1].health, money = run.money, logs = run.logs })
check("P04", "饥荒归零连续粮年", run.metrics.foodYears == 0, "foodYears=0", { foodYears = run.metrics.foodYears })

run, profile, draft = fresh()
assert(Simulation.Marry(run, 3)); local spouse = State.FindMember(run.members, run.members[3].spouseId)
run.members[3].jobYears.teach = 2; spouse.jobYears.teach = 2
local generations = Simulation.EndingProgress(run, "scholar")[1][2]
check("P05", "真实婚入的同辈夫妻只算一代教书", generations == 1, "one occupational generation", { spouseGeneration = spouse.generation, recomputed = State.Generation(run.members, spouse.id), occupationalGenerations = generations })

-- Seed 1 and age 89 cause leader death through the unmodified annual PRNG.
run, profile, draft = fresh()
run.members = { run.members[1], run.members[2] }; run.members[1].age = 89; run.members[2].age = 30
for _, person in ipairs(run.members) do person.spouseId = nil; person.birthPlan = false end
run.rngState = 1
assert(Simulation.AdvanceYear(run, profile))
assert(not run.members[1].alive and run.members[2].alive, "death fixture did not create unique successor")
local event = Simulation.PendingEvents(run)[1]; assert(event and event.type == "leader")
fixtures.succession = { profile = State.Copy(profile), draft = State.Copy(draft), run = State.Copy(run) }
local custodian = State.FindMember(run.members, run.relicInstances[1].custodianId)
check("P06", "死亡保管人回收到家中或在世族人", custodian == nil or custodian.alive, "house custody or living member", { custodianId = run.relicInstances[1].custodianId, alive = custodian and custodian.alive })
local normal = State.Copy(run)
local invalidLeader = Simulation.ResolveLeaderEvent(normal, event.instanceId, 999)
local normalOk = Simulation.ResolveLeaderEvent(normal, event.instanceId, 2)
local repeatOk = Simulation.ResolveLeaderEvent(normal, event.instanceId, 2)
local nextYear = Simulation.AdvanceYear(normal, profile)
check("G03", "事件入口继任可继续，非法和重复任命拒绝", not invalidLeader and normalOk and not repeatOk and nextYear,
    "invalid=false, valid=true, repeat=false, nextYear=true", { invalid = invalidLeader, normal = normalOk, repeated = repeatOk, nextYear = nextYear, terms = normal.leaderTerms })
local manual = Simulation.AppointLeader(run, 2, "主动交接")
local resolve, reason = Simulation.ResolveLeaderEvent(run, event.instanceId, 2)
local advance = Simulation.AdvanceYear(run, profile)
run = saveLoad(run, profile, draft); fixtures.blockedSuccession = { profile = profile, draft = draft, run = State.Copy(run) }
check("P07", "人物入口继任同步关闭事件并可继续", manual and resolve and advance and #Simulation.PendingEvents(run) == 0,
    "one handover, no pending leader event, advance succeeds", { manual = manual, resolve = resolve, advance = advance, reason = reason, pending = Simulation.PendingEvents(run), terms = run.leaderTerms })

draft = State.NewDraft(); draft.originId = "gentry"; draft.tieId = "neighbor"; draft.money = 0; draft.grain = 0; draft.land = 0; draft.selectedRelicIds = {}
run = assert(State.NewRun(draft, State.NewProfile()))
check("P08", "两项已付费声望独立叠加", run.reputation == 37, "25+12=37 (current declared contributions)", { points = State.TotalPoints(draft), reputation = run.reputation })

-- Profile preservation: run actual investigation -> unlock -> save -> App.Init -> StartRun.
run, profile, draft = fresh()
assert(Simulation.StartRelicInvestigation(run, "relic-1", "fast")); assert(Simulation.AdvanceYear(run, profile))
event = Simulation.PendingEvents(run)[1]; assert(event.type == "relic_resolution")
assert(Simulation.ResolveEvent(run, event.instanceId, "restore", profile)); assert(profile.unlockedRelicIds.plan)
assert(State.Save(profile, draft, run)); fixtures.unlocked = assert(State.Load())
app = App.New(); app:StartRun()
local restart = assert(State.Load())
check("F01", "重启直接新开保留已解锁营造图", restart.profile.unlockedRelicIds.plan == true,
    "plan unlocked before and after restart/new run", { before = true, after = restart.profile.unlockedRelicIds.plan == true, total = State.TotalPoints(restart.draft) })

-- Existing cancellation path is an actual sale, not closing a UI or a fake defer.
run, profile, draft = fresh()
assert(Simulation.StartRelicInvestigation(run, "relic-1", "fast")); assert(Simulation.AdvanceYear(run, profile))
local logCount = #run.logs; local sold = Simulation.SellRelic(run, "relic-1")
local money = run.money; local resell = Simulation.SellRelic(run, "relic-1")
local restore = Simulation.ResolveEvent(run, run.events[1].instanceId, "restore", profile)
check("G04", "出售信物取消待决奖励、保留历史、重复不付", sold and not resell and not restore and money == run.money and not profile.unlockedRelicIds.plan and #run.logs > logCount,
    "cancelled event, no plan reward, no double sale, history retained", { status = run.events[1].status, sold = sold, resell = resell, restore = restore, money = run.money, historyCount = #run.logs })

local bad = State.Import('{"profile":{"schemaVersion":999},"draft":{"members":[]}}')
local malformed = State.Import('{broken')
local oldRaw = storage.files["jiaye_save.json"]
storage.failOpen = true
local saveOk = State.Save(profile, draft, run)
app = App.New(); app:Export(); local exportNotice = notices[#notices]
storage.failOpen = false; storage.failWrite = true
local shortWriteOk = State.Save(profile, draft, run)
storage.failWrite = false
check("F02", "坏结构/写失败不假报成功", bad == nil and malformed == nil and not saveOk and exportNotice.variant ~= "success" and not shortWriteOk,
    "reject invalid schema; report save/export/short-write failures; keep previous payload", { malformedRejected = malformed == nil, badStructureAccepted = bad ~= nil, openFailureReported = not saveOk, exportNotice = exportNotice, shortWriteAccepted = shortWriteOk, oldPayloadUnchanged = storage.files["jiaye_save.json"] == oldRaw })

app = App.New(); app.screen = "opening"; app.openingPage = "estate"; app:Render()
local stepper = assert(find(UI.root, function(node) return node.kind == "Stepper" and node.value == 80 end))
stepper.onChange(stepper, 110)
local label100 = find(UI.root, function(node) return node.kind == "Label" and node.text:find("总分 100/100", 1, true) end)
local label97 = find(UI.root, function(node) return node.kind == "Label" and node.text:find("总分 97/100", 1, true) end)
check("F03", "钱数回调后预算组件立即一致", label100 ~= nil and label97 == nil,
    "100/100 visible in existing component tree", { actualTotal = State.TotalPoints(app.draft), stale97 = label97 ~= nil, fresh100 = label100 ~= nil, previewBound = app.previewLabel ~= nil })

-- Sample additional validation gaps without claiming the whole schema is audited.
draft = State.NewDraft(); draft.members[3].jobId = "official"
local unearnedOffice = State.NewRun(draft, State.NewProfile())
draft = State.NewDraft(); draft.members[1].spouseId = 1; draft.members[2].spouseId = nil
local selfSpouse = State.NewRun(draft, State.NewProfile())
draft = State.NewDraft(); draft.money = 111
local fractional = State.NewRun(draft, State.NewProfile())
check("F04", "未经应试/自婚/100.1 点输入拒绝", unearnedOffice == nil and selfSpouse == nil and fractional == nil,
    "all rejected; off-step resource rejected or accurately priced", { unearnedOfficeAccepted = unearnedOffice ~= nil, selfSpouseAccepted = selfSpouse ~= nil, money111Points = State.TotalPoints(draft), money111Accepted = fractional ~= nil })

return { default = default, fixtures = fixtures, results = results }
