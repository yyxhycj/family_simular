-- 开局验收专用入口；正式 main.lua 不引用。真实 UI/cjson/File，存档统一隔离为 opening_qa_ 前缀。
---@diagnostic disable: undefined-global, assign-type-mismatch
local UI = require "urhox-libs/UI"
local nativeFile, nativeFS = File, fileSystem

local function PathFor(path)
    if path == "jiaye_save.json" or path == "jiaye_save.backup.json" or path == "jiaye_export.json" then
        return "opening_qa_" .. path
    end
    return path
end

File = function(path, mode)
    return nativeFile(PathFor(path), mode)
end
fileSystem = { FileExists = function(_, path) return nativeFS:FileExists(PathFor(path)) end }

local Data = require "Jiaye.Data"
local Opening = require "Jiaye.Opening"
local State = require "Jiaye.State"
local App = require "Jiaye.App"

local sizes = {
    { id = "360", label = "360 × 800", width = 360, height = 800 },
    { id = "390", label = "390 × 844", width = 390, height = 844 },
    { id = "430", label = "430 × 932", width = 430, height = 932 },
}
local size = sizes[2]
local currentApp = nil
local ShowMenu

local function RunSummary(run)
    if not run then return nil end
    return {
        openingSnapshot = run.openingSnapshot,
        yearIndex = run.yearIndex,
        money = run.money,
        grain = run.grain,
        lastLedger = run.lastLedger,
        rngState = run.rngState,
    }
end

local function Emit(app)
    local saved = State.Load()
    print("OPENING_QA " .. cjson.encode({
        frame = { width = size.width, height = size.height },
        screenMetrics = {
            physicalWidth = graphics:GetWidth(),
            physicalHeight = graphics:GetHeight(),
            dpr = graphics:GetDPR(),
            scale = UI.Scale.DEFAULT(),
        },
        screen = app.screen,
        view = app.openingView,
        page = app.openingPage,
        points = State.TotalPoints(app.draft),
        draft = app.draft,
        profile = app.profile,
        run = RunSummary(app.run),
        saved = saved and { profile = saved.profile, draft = saved.draft, run = RunSummary(saved.run) } or nil,
    }))
end

local realRender = App.Render
function App:Render()
    realRender(self)
    local phoneFrame = self.root:GetChildAt(1)
    if phoneFrame then
        phoneFrame:SetWidth(size.width)
        phoneFrame:SetHeight(size.height)
    end
    self.root:AddChild(UI.Button {
        text = "验收菜单",
        position = "absolute",
        top = 6,
        right = 6,
        height = 32,
        fontSize = 12,
        backgroundColor = { 232, 239, 221, 255 },
        textColor = { 38, 60, 51, 255 },
        onClick = function() ShowMenu() end,
    })
    Emit(self)
end

local function FreshApp(profile, draft)
    local app = App.New()
    app.profile = profile
    app.draft = draft
    app.run = nil
    app.previousDraft = nil
    app.editBackup = nil
    app.houseUndo = nil
    app.undo = {}
    app.screen = "opening"
    app.openingView = "summary"
    app.openingPage = "world"
    app.openingGenerationFailed = false
    currentApp = app
    app:Render()
end

local function Generate(seed, unlockAll)
    local profile = State.NewProfile()
    local draft, issue = Opening.Generate(profile, seed, "mortal")
    assert(draft, issue)
    -- seed 722 的六人夹具以初始池生成；随后只扩展 Profile 解锁池，不重掷本户或强行全选信物。
    if unlockAll then
        assert(#draft.members == 6, "seed 722 未生成六人夹具")
        for _, relic in ipairs(Data.Relics) do profile.unlockedRelicIds[relic.id] = true end
    end
    FreshApp(profile, draft)
end

local function ShowSeed20260917()
    Generate(20260917, false)
end

local function ShowSeed722()
    Generate(722, true)
end

local function ShowOverBudget()
    local profile, draft = State.NewProfile(), State.NewDraft()
    draft.money = 130 -- 固定 102/100 边界夹具；不可开始但可在摘要查看错误。
    FreshApp(profile, draft)
end

local function LoadIsolated()
    local app = App.New()
    app:Load()
    currentApp = app
    if not app.root then app:Render() end -- 无隔离存档时仍展示“尚无存档”及对应 OPENING_QA。
end

ShowMenu = function()
    currentApp = nil
    local children = {
        UI.Label { text = "Opening 开局隔离验收", fontSize = 24, fontWeight = "bold" },
        UI.Label { text = "只读写 opening_qa_ 存档；正式家谱与 main.lua 均不受影响。", whiteSpace = "normal", fontSize = 15 },
        UI.Label { text = "逻辑 frame：" .. size.label .. "（不缩放）", fontSize = 15 },
    }
    for _, item in ipairs(sizes) do
        local target = item
        table.insert(children, UI.Button { text = "尺寸 " .. target.label, onClick = function()
            size = target
            ShowMenu()
        end })
    end
    table.insert(children, UI.Button { text = "1 · seed 20260917 随机开局摘要", onClick = ShowSeed20260917 })
    table.insert(children, UI.Button { text = "2 · seed 722 · 六人 · 解锁 7 件池", onClick = ShowSeed722 })
    table.insert(children, UI.Button { text = "3 · 固定超分草案 · 130 两 / 102 点", onClick = ShowOverBudget })
    table.insert(children, UI.Button { text = "4 · 读取 opening_qa_ 最近进度", onClick = LoadIsolated })
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", alignItems = "center",
        children = { UI.Panel { width = size.width, height = size.height, maxWidth = "100%", gap = 12, padding = 16, children = children } } }, true)
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    ShowMenu()
    print("OPENING_QA_READY 开局隔离验收；选择夹具后输出 OPENING_QA JSON。")
end

function Stop()
    currentApp = nil
    UI.Shutdown()
end
