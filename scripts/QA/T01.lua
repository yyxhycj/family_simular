-- 独立验收入口；正式 main.lua 不引用。使用真实 UI/cjson/File，存档名隔离。
---@diagnostic disable: assign-type-mismatch, undefined-global
local UI = require "urhox-libs/UI"
local nativeFile, nativeFS = File, fileSystem
local shortWrite = false
local function pathFor(path)
    if path == "jiaye_save.json" or path == "jiaye_save.backup.json" or path == "jiaye_export.json" then
        return "t01_qa_" .. path
    end
    return path
end
File = function(path, mode)
    local file = nativeFile(pathFor(path), mode)
    if shortWrite and mode == FILE_WRITE then
        shortWrite = false
        return {
            IsOpen = function() return file:IsOpen() end,
            WriteString = function(_, raw) return file:WriteString(raw:sub(1, 12)) end,
            Close = function() file:Close() end,
        }
    end
    return file
end
fileSystem = { FileExists = function(_, path) return nativeFS:FileExists(pathFor(path)) end }

local State = require "Jiaye.State"
local Sim = require "Jiaye.Simulation"
local App = require "Jiaye.App"
local function summary(run)
    if not run then return {} end
    return { year = run.yearIndex, money = run.money, grain = run.grain, leader = run.leaderId,
        terms = run.leaderTerms, pending = #Sim.PendingEvents(run), logs = #run.logs,
        oldest = run.logs[#run.logs], rng = run.rngState, aid = run.metrics.aid,
        relics = run.relicInstances, events = run.events }
end
local realRender = App.Render
function App:Render()
    realRender(self)
    local saved = State.Load()
    print("T01_QA " .. cjson.encode({ screen = self.screen, tab = self.gameTab, page = self.historyPage,
        unsaved = self.unsaved, shown = summary(self.run), saved = summary(saved and saved.run),
        unlocked = self.profile.unlockedRelicIds, points = State.TotalPoints(self.draft) }))
end

local function fixture(kind)
    local profile, draft = State.NewProfile(), State.NewDraft()
    local run = assert(State.NewRun(draft, profile))
    if kind == "history" then
        for i = 1, 151 do State.AddLog(run, "隔离验收家史第 " .. i .. " 条") end
    elseif kind == "event" or kind == "member" then
        run.members = { run.members[1], run.members[2] }
        run.members[1].age = 89; run.members[2].age = 30
        for _, member in ipairs(run.members) do member.spouseId = nil; member.birthPlan = false end
        run.rngState = 1
        assert(Sim.AdvanceYear(run, profile))
        assert(not run.members[1].alive and run.members[2].alive and Sim.PendingEvents(run)[1].type == "leader")
    elseif kind == "collection" then
        assert(Sim.StartRelicInvestigation(run, "relic-1", "fast"))
        assert(Sim.AdvanceYear(run, profile))
        assert(Sim.ResolveEvent(run, Sim.PendingEvents(run)[1].instanceId, "restore", profile))
        assert(profile.unlockedRelicIds.plan)
    end
    assert(State.Save(profile, draft, run))
    local app = App.New(); app:Load()
    if kind == "history" then app.gameTab = "history"
    elseif kind == "member" then app.gameTab = "people"
    elseif kind == "collection" then
        app:PrepareNewRun(); app:ToggleRelic("plan"); app.draft.money = 0
        assert(State.TotalPoints(app.draft) == 99)
        app.openingPage = "relics"
    elseif kind == "failure" then
        shortWrite = true
        app:RunAction(function() return Sim.AidCommunity(app.run) end)
        assert(app.unsaved and app.run.money == 65 and State.Load().run.money == 80)
    end
    app:Render()
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    local children = {
        UI.Label { text = "T01 隔离验收", fontSize = 24 },
        UI.Label { text = "只使用 t01_qa_ 存档，原家谱不动。夹具用于验收，不代表玩家经历。", whiteSpace = "normal" },
        UI.Button { text = "读取隔离进度（重启核对）", onClick = function() local app = App.New(); app:Load() end },
    }
    local cases = { { "151 条家史", "history" }, { "唯一成年继任 · 事件入口", "event" },
        { "唯一成年继任 · 人物入口", "member" }, { "真实解锁后试配新局 · 99 点", "collection" },
        { "注入一次短写 · 重试不重复扣款", "failure" } }
    for _, item in ipairs(cases) do
        local kind = item[2]
        table.insert(children, UI.Button { text = item[1], onClick = function()
            local ok, err = pcall(fixture, kind)
            if not ok then print("T01_QA_FAIL " .. tostring(err)); UI.Toast.Show(tostring(err), { variant = "error" }) end
        end })
    end
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", alignItems = "center",
        children = { UI.Panel { width = 420, maxWidth = "100%", gap = 12, padding = 16, children = children } } })
    print("T01_QA_READY 隔离验收；真实 File/cjson/UI，原家谱不动。")
end

function Stop()
    UI.Shutdown()
end
