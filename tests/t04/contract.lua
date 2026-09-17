-- T04 只验证随机开局摘要的字段绑定、可达明细与开始快照；不把声明式 UI 适配层当作真机布局验收。
local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Data = require "Jiaye.Data"
local Economy = require "Jiaye.Economy"
local Opening = require "Jiaye.Opening"
local State = require "Jiaye.State"

local function same(left, right) return Opening.Equal(left, right) end

local function find(root, matches)
    if matches(root) then return root end
    for _, child in ipairs(root.children or {}) do
        local found = find(child, matches)
        if found then return found end
    end
end

local function text(root, value)
    return find(root, function(node) return node.text == value end)
end

local function prefix(root, value)
    return find(root, function(node) return type(node.text) == "string" and node.text:sub(1, #value) == value end)
end

local function contains(root, value)
    return find(root, function(node) return type(node.text) == "string" and node.text:find(value, 1, true) ~= nil end)
end

local function id(root, value)
    return find(root, function(node) return node.id == value end)
end

local function run()
    local profile = State.NewProfile()
    local draft = assert(Opening.Generate(profile, 722, "mortal"))
    local app = App.New()
    app.profile, app.draft, app.run = profile, State.Copy(draft), nil
    app.screen, app.openingView = "opening", "summary"
    app:Render()

    local leader = assert(State.FindMember(app.draft.members, app.draft.leaderId))
    local forecast = Economy.Preview(assert(State.NewRun(app.draft, profile)))
    assert(text(UI.root, app.draft.family .. "氏家族"), "摘要必须绑定当前生成家族名")
    for _, value in ipairs({ app.draft.money .. " 两", app.draft.grain .. " 石", app.draft.land .. " 亩" }) do
        assert(text(UI.root, value), "摘要缺少当前资产：" .. value)
    end
    assert(text(UI.root, "首任族长 · " .. leader.name .. " · " .. Data.Jobs[leader.jobId].name), "摘要缺少首任族长的初始安排")
    assert(text(UI.root, "首年预计净变化") and id(UI.root, "opening-ledger-detail"), "摘要缺少同源的首年净变化入口")
    assert(prefix(UI.root, "总计 "), "摘要缺少开局总分入口")
    for index = 1, math.min(4, #app.draft.members) do
        assert(contains(UI.root, app.draft.members[index].name), "摘要缺少成员入口：" .. app.draft.members[index].name)
    end
    if #app.draft.members > 4 then assert(text(UI.root, "查看全部 " .. #app.draft.members .. " 人  ›"), "摘要缺少完整成员入口") end
    assert(id(UI.root, "opening-relic-detail"), "摘要缺少信物明细入口")

    -- 多件信物不能只显示第一件；细节仍由同一个入口查看。
    local validDraft = State.Copy(app.draft)
    app.draft.selectedRelicIds = { "book", "ruler", "letter" }
    app:Render()
    assert(contains(UI.root, "一本旧族谱 · 6 点；一把老木尺 · 6 点；其余 1 件"), "多件信物摘要没有显示前两件与剩余数量")
    app.draft = validDraft
    app:Render()

    -- 摘要中的真实按钮只切换只读明细，不能重掷或改写草案。
    local details = {
        { node = function() return id(UI.root, "opening-points-detail") end, view = "points" },
        { node = function() return id(UI.root, "opening-ledger-detail") end, view = "ledger" },
        { node = function() return id(UI.root, "opening-relic-detail") end, view = "relics" },
    }
    local stableDraft = State.Copy(app.draft)
    for _, detail in ipairs(details) do
        local button = assert(detail.node(), "摘要明细入口不可达：" .. detail.view)
        button.onClick(button)
        assert(app.openingView == detail.view and same(app.draft, stableDraft), "打开明细改变了草案：" .. detail.view)
        app:ReturnOpeningDetail()
        assert(app.openingView == "summary" and same(app.draft, stableDraft), "返回摘要改变了草案：" .. detail.view)
    end
    app:OpenOpeningDetail("people")
    assert(app.openingView == "people" and same(app.draft, stableDraft), "打开全体成员明细改变了草案")
    app:ReturnOpeningDetail()

    -- "换一家"与恢复由真实摘要按钮发起；原运行局尚不存在时也不得产生额外存档。
    local change = assert(id(UI.root, "opening-change-house"))
    change.onClick(change)
    assert(app.houseUndo and not same(app.draft, stableDraft) and State.Load() == nil, "换一家未生成新草案或提前写入存档")
    local undo = assert(text(UI.root, "恢复上一家"))
    undo.onClick(undo)
    assert(same(app.draft, stableDraft), "恢复上一家未还原展示草案")

    -- 封面沿用纸面信息层级，关键入口保持可读。
    app.screen = "cover"; app:Render()
    assert(assert(text(UI.root, "家业")).fontSize == 29 and text(UI.root, "凡世王朝 · " .. Data.WORLD_NAME), "封面没有使用家业与凡世王朝的纸面标题")
    assert(contains(UI.root, "默认会生成一户完整且合法的人家") and text(UI.root, "完整家谱") and text(UI.root, "钱粮预估"), "封面没有说明生成家庭与可核对的开局信息")
    assert(assert(text(UI.root, "立一部家谱")).fontSize == 17, "封面按钮仍被全局缩小")
    app.screen = "opening"; app.openingView = "summary"; app:Render()

    -- 首次开始没有覆盖确认；写入的运行快照就是眼前草案。
    app:StartRun()
    assert(app.screen == "game" and app.run and same(stableDraft, app.run.openingSnapshot), "首次开始没有使用正在展示的草案")
    assert(same(State.Load().draft, stableDraft) and same(State.Load().run, app.run), "首次开始的草案、运行局与存档不一致")
    assert(same(forecast, Economy.Preview(app.run)), "开始后的首年预估没有沿用摘要计算核")

    -- 已有旧局时，取消不覆盖；确认一次后才替换，重复确认无效。
    local oldRun = State.Copy(app.run)
    app:PrepareNewRun()
    local replacement = State.Copy(app.draft)
    app:StartRun()
    local cancel = assert(text(UI.modal, "取消"))
    cancel.onClick(cancel)
    assert(same(app.run, oldRun) and same(State.Load().run, oldRun) and same(app.draft, replacement), "取消替换覆盖了旧局或展示草案")
    app:StartRun()
    local confirm = assert(text(UI.modal, "确认开始"))
    confirm.onClick(confirm)
    local replaced = State.Copy(app.run)
    confirm.onClick(confirm)
    assert(same(app.run, replaced) and same(app.run.openingSnapshot, replacement) and same(State.Load().run, replaced), "确认替换未保持快照，或重复确认重复提交")

    -- 非法候选在摘要页禁用开始，也不得覆盖已经保存的家谱。
    local storedRun = State.Copy(app.run)
    app:PrepareNewRun()
    app.draft.money = 999
    app:Render()
    assert(assert(id(UI.root, "opening-start")).disabled, "非法草案的开始按钮没有禁用")
    app:StartRun()
    assert(same(app.run, storedRun) and same(State.Load().run, storedRun) and app.openingFeedback ~= "", "非法草案覆盖了旧局或未就地说明")

    return {
        id = "opening_summary",
        seed = 722,
        family = stableDraft.family,
        population = #stableDraft.members,
        leaderJob = Data.Jobs[leader.jobId].name,
        details = 4,
        changeHouseUndo = true,
        summaryToRunSnapshot = true,
        oldRunCancelPreserved = true,
        invalidStartBlocked = true,
    }
end

local function restart()
    local app = App.New()
    assert(app.screen == "cover" and app.run, "新 Lua 进程没有保留可继续的家谱")
    app:Load()
    assert(app.screen == "game" and app.run, "重新读取存档后没有进入已确认的新局")
    assert(same(app.run.openingSnapshot, app.draft) and same(State.Load().run, app.run), "重启后状态、快照与存档不一致")
    return { id = "restart", family = app.draft.family, population = #app.draft.members, year = app.run.yearIndex }
end

return { run = run, restart = restart }
