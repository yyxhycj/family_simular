---@diagnostic disable: undefined-global
local UI = require "urhox-libs/UI"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Opening = require "Jiaye.Opening"
local App = require "Jiaye.App"

local function FindGeneratedRun(profile)
    for seed = 1, 4096 do
        local draft = Opening.Generate(profile, seed, "mortal")
        if draft and draft.money >= 60 and #draft.members >= 3 then
            draft.members[1].name = "南宫长乐甲乙丙丁戊己庚辛壬癸子丑寅卯"
            local run, issues = State.NewRun(draft, profile)
            if run then return run, draft end
            error(table.concat(issues or {}, "；"))
        end
    end
    error("未找到可验收的真实开局家庭。")
end

local function HasFact(run, kind)
    for _, fact in ipairs(run.facts or {}) do if fact.kind == kind then return fact end end
    return nil
end

local function HasRelic(draft, relicId)
    for _, id in ipairs(draft.selectedRelicIds or {}) do if id == relicId then return true end end
    return false
end

local function CheckEconomyAndHistory(lines)
    local profile = State.NewProfile()
    local run = FindGeneratedRun(profile)
    local quote, message = Simulation.GrainPurchaseQuote(run, 2)
    assert(quote, message)
    local beforeMoney, beforeGrain = run.money, run.grain
    local ok
    ok, message = Simulation.BuyGrain(run, 2)
    assert(ok, message)
    assert(run.money == beforeMoney - quote.price and run.grain == beforeGrain + 2, "购粮结果未按同源报价入账。")
    local grainFact = HasFact(run, "grain_purchase")
    assert(grainFact and grainFact.amount == 2 and grainFact.price == quote.price, "购粮事实记录缺失。")
    beforeMoney, beforeGrain = run.money, run.grain
    ok, message = Simulation.BuyGrain(run, 0)
    assert(not ok and run.money == beforeMoney and run.grain == beforeGrain, "非法购粮改变了资源。")
    ok, message = Simulation.BuyGrain(run, beforeMoney + 1)
    assert(not ok and run.money == beforeMoney and run.grain == beforeGrain, "公库不足时购粮改变了资源。")

    beforeMoney = run.money
    ok, message = Simulation.BuyAsset(run, "land")
    assert(ok, message)
    assert(run.money == beforeMoney - 30 and run.land >= 1, "购田结果未按运行时价格入账。")
    local assetFact = HasFact(run, "asset_purchase")
    assert(assetFact and assetFact.assetId == "land" and assetFact.price == 30, "置办家业事实记录缺失。")
    table.insert(lines, "公市购粮、运行时置办、事实记录与资源变化同源")
    return run, profile
end

local function CheckEventResolution(lines)
    local profile = State.NewProfile()
    for seed = 1, 4096 do
        local draft = Opening.Generate(profile, seed, "mortal")
        if draft and draft.money >= 30 and HasRelic(draft, "ruler") then
            local run, issues = State.NewRun(draft, profile)
            assert(run, table.concat(issues or {}, "；"))
            local ruler = nil
            for _, instance in ipairs(run.relicInstances) do if instance.definitionId == "ruler" then ruler = instance end end
            assert(ruler, "真实开局没有带入老木尺实例。")
            local ok, message = Simulation.StartRelicInvestigation(run, ruler.instanceId, "fast")
            assert(ok, message)
            ok, message = Simulation.AdvanceYear(run, profile)
            assert(ok, message)
            local event = nil
            for _, item in ipairs(Simulation.PendingEvents(run)) do if item.type == "relic_resolution" then event = item end end
            assert(event, "真实调查到期后没有生成待决事件。")
            ok, message = Simulation.ResolveEvent(run, event.instanceId, "defer", profile)
            assert(ok, message)
            assert(event.status == "resolved" and ruler.stage == "clue_saved", "事件结果未同步写入物件状态。")
            table.insert(lines, "真实信物调查生成待决事件，处理结果同步到物件状态与家史")
            return
        end
    end
    error("未找到带老木尺的真实生成家庭。")
end

local function CheckRealViews(run, profile, lines)
    local app = App.New()
    app.profile = profile
    app.run = run
    app.draft = State.Copy(run.openingSnapshot)
    app.screen = "game"
    for _, tab in ipairs({ "family", "people", "estate", "relics", "history" }) do
        app.gameTab = tab
        app:Render()
    end
    assert(State.ValidName(run.members[1].name), "长名成员未通过真实姓名校验。")
    assert(#run.members >= 3 and State.Generation(run.members, run.members[1].id) >= 1, "家谱成员或代际数据缺失。")
    table.insert(lines, "家事、族人、家业、藏阁、家史均以同一份运行存档完成实际 UI 构建")
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    local lines = { "T09 真实引擎验收通过" }
    local run, profile = CheckEconomyAndHistory(lines)
    CheckEventResolution(lines)
    CheckRealViews(run, profile, lines)
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", alignItems = "center", children = {
        UI.Panel { width = 430, maxWidth = "100%", gap = 12, padding = 16, children = (function()
            local children = { UI.Label { text = lines[1], fontSize = 24 } }
            for index = 2, #lines do table.insert(children, UI.Label { text = "• " .. lines[index], whiteSpace = "normal" }) end
            return children
        end)() },
    } })
    print("T09_QA_PASS " .. table.concat(lines, " | "))
end

function Stop()
    UI.Shutdown()
end
