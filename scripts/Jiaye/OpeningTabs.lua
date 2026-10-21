local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Art = require "Jiaye.Art"
local Skin = require "Jiaye.QianjiajiSkin"

local OpeningTabs = {}
local C = Skin.Colors
local tabs = {
    {id = "overview", label = "总览"}, {id = "family", label = "家族"}, {id = "estate", label = "家业"},
    {id = "people", label = "族人"}, {id = "relics", label = "旧物"}, {id = "forecast", label = "收支"},
}
local numerals = {"一", "二", "三", "四", "五", "六"}

local function text(value, size, color, props)
    local p = props or {}
    p.fontSize, p.fontColor = size or 16, color or C.ink
    return Skin.Text(value, p)
end

local function row(children, props)
    local p = props or {}
    p.width, p.gap, p.alignItems, p.flexShrink, p.children = "100%", p.gap or 10, "center", 0, children
    return UI.Row(p)
end

local function signed(value)
    return (value > 0 and "+" or "") .. tostring(value)
end

local function entry(id, children, action, props)
    local p = props or {}
    p.id, p.width, p.flexShrink, p.pointerEvents, p.onClick = id, "100%", 0, "box-only", action
    p.minHeight, p.borderRadius = p.minHeight or 52, 0
    p.borderBottomWidth, p.borderBottomColor = p.borderBottomWidth or 1, C.rule
    p.children = {row(children)}
    return UI.Panel(p)
end

local function heading(title, label, action, id)
    return row({text(title, 22), UI.Panel {flex = 1}, Skin.TextAction(label, action, {id = id, fontSize = 14})})
end

local function resources(draft, compact)
    local children = {}
    for _, item in ipairs({{"现银", draft.money, "两"}, {"存粮", draft.grain, "石"}, {"田地", draft.land, "亩"}}) do
        children[#children + 1] = UI.Panel {flex = 1, minWidth = 0, alignItems = "center", gap = compact and 3 or 8, children = {
            text(item[1], 12, C.muted), text(item[2] .. " " .. item[3], compact and 21 or 26),
        }}
    end
    return row(children, {paddingVertical = compact and 9 or 18})
end

local function memberCard(app, member, compact)
    local labels = UI.Panel {minWidth = 0, gap = 3, children = {
        text(member.name, compact and 14 or 18),
        text(member.age .. " 岁 · " .. Data.Jobs[member.jobId].name, compact and 10 or 12, C.muted),
        text(member.id == app.draft.leaderId and "首任族长" or ("资质 " .. member.talent .. " / 5"), compact and 10 or 12,
            member.id == app.draft.leaderId and C.red or C.muted),
    }}
    if compact then
        labels:SetStyle({flex = 1})
        return row({Skin.Image(Art.Portrait(member), {width = 38, height = 56}), labels}, {flex = 1, minWidth = 0, gap = 5})
    end
    return UI.Panel {id = "opening-person-" .. member.id, flexShrink = 0, minWidth = 0, gap = 8, paddingVertical = 10,
        pointerEvents = "box-only", onClick = function() app:OpenOpeningDetail("person", member.id) end, children = {
            Skin.Image(Art.Portrait(member), {width = "100%", height = 112}), labels,
        }}
end

local function overview(app, model, select)
    local draft, forecast, relics = app.draft, model.forecast, model.relics
    local place, period = Data.Place(draft.placeId), Data.Period(draft.periodId)
    local family = {}
    for index = 1, math.min(2, #draft.members) do family[#family + 1] = memberCard(app, draft.members[index], true) end
    local relicNames = {}
    for index = 1, math.min(2, #relics) do relicNames[#relicNames + 1] = relics[index].name end
    if #relics > 2 then relicNames[#relicNames + 1] = "等 " .. #relics .. " 件" end
    return {
        entry("opening-overview-family", {UI.Panel {flex = 1, minWidth = 0, gap = 4, children = {
            text(draft.family .. "氏家谱", 27), text("大晟历 " .. draft.calendar .. " 年 · " .. period.name .. " · " .. place.short, 11, C.muted),
        }}, text("改写 ›", 12, C.muted)}, function() select("family") end, {minHeight = 70}),
        entry("opening-overview-estate", {UI.Panel {flex = 1, minWidth = 0, gap = 3, children = {
            text("家业", 11, C.muted), text(Data.Home(draft.homeId).name, 20),
            text((draft.workshop and "有作坊" or "无作坊") .. " · " .. (draft.shop and "有商铺" or "无商铺"), 11, C.muted),
        }}, Skin.Image(Art.House(draft.homeId, "normal"), {width = "38%", height = 72}), Skin.Icon("chevron_right", 14)},
            function() select("estate") end, {minHeight = 80}),
        entry("opening-overview-resources", {resources(draft, true)}, function() select("estate") end),
        UI.Panel {id = "opening-overview-people", gap = 6, paddingVertical = 9, flexShrink = 0, borderRadius = 0,
            borderBottomWidth = 1, borderBottomColor = C.rule, pointerEvents = "box-only", onClick = function() select("people") end, children = {
                row({text("家中 " .. #draft.members .. " 人", 15), UI.Panel {flex = 1}, text(model.adults .. " 成人 · " .. (#draft.members - model.adults) .. " 孩子 ›", 11, C.muted)}),
                row(family, {gap = 8}),
            }},
        entry("opening-overview-relics", {#relics > 0 and Skin.Image(Art.Relic(relics[1].id), {width = 44, height = 48}) or Skin.Icon("book", 30),
            UI.Panel {flex = 1, minWidth = 0, gap = 3, children = {text("家传旧物 · " .. #relics .. " 件", 11, C.muted),
                text(#relics > 0 and table.concat(relicNames, " · ") or "空手开篇", 16)}}, Skin.Icon("chevron_right", 14)},
            function() select("relics") end, {minHeight = 60}),
        entry("opening-overview-forecast", {UI.Panel {flex = 1, minWidth = 0, gap = 3, children = {text("首年预计", 16), text("不含突发", 11, C.muted)}},
            text(forecast and (signed(forecast.netMoney) .. " 两  " .. signed(forecast.netGrain) .. " 石") or "请先修正草案", 18),
            Skin.Icon("chevron_right", 14)}, function() select("forecast") end, {minHeight = 56}),
    }
end

local function family(app)
    local draft = app.draft
    local background = State.BackgroundDefinition(draft)
    return {
        Skin.Image(Skin.Art.world, {width = "100%", height = 126}),
        row({text(draft.family .. "氏家谱", 30), UI.Panel {flex = 1}, Skin.IconAction("edit", function() app:BeginOpeningEdit("name") end, {id = "opening-edit-name"})}),
        text("大晟历 " .. draft.calendar .. " 年 · " .. Data.Place(draft.placeId).short, 13, C.muted),
        entry("opening-edit-world", {text("时世与地域", 16), UI.Panel {flex = 1},
            text(Data.Period(draft.periodId).name .. " · " .. Data.Place(draft.placeId).short .. " ›", 13, C.muted)}, function() app:BeginOpeningEdit("world") end),
        entry("opening-edit-origin", {text("家族出身", 16), UI.Panel {flex = 1}, text(background.name .. " ›", 14, C.muted)}, function() app:BeginOpeningEdit("origin") end),
        text(background.history, 14, C.muted),
        Skin.TextAction("另择一姓", function() app:RandomFamilyName() end, {id = "opening-random-name", fontSize = 15}),
    }
end

local function estate(app)
    local draft = app.draft
    return {
        heading("安家置业", "置办 ›", function() app:BeginOpeningEdit("estate") end, "opening-edit-estate"),
        Skin.Image(Art.House(draft.homeId, "normal"), {width = "100%", height = 150}),
        text(Data.Home(draft.homeId).name, 24, C.ink, {textAlign = "center", width = "100%"}),
        text((draft.workshop and "有作坊" or "无作坊") .. " · " .. (draft.shop and "有商铺" or "无商铺"), 13, C.muted, {textAlign = "center", width = "100%"}),
        resources(draft), Skin.Line(),
        Skin.TextAction("调整家宅、田地与积蓄 ›", function() app:BeginOpeningEdit("estate") end, {id = "opening-estate-adjust", fontSize = 15}),
    }
end

local function people(app, model)
    local members = {}
    for index = 1, #app.draft.members, 2 do
        local left = memberCard(app, app.draft.members[index], false)
        left:SetStyle({flex = 1})
        local right = app.draft.members[index + 1] and memberCard(app, app.draft.members[index + 1], false) or UI.Panel {}
        right:SetStyle({flex = 1, minWidth = 0})
        members[#members + 1] = row({left, right}, {gap = 14, paddingVertical = 2})
    end
    return {
        heading("家中族人", "调整 ›", function() app:BeginOpeningEdit("people") end, "opening-edit-family"),
        text(model.adults .. " 成人 · " .. (#app.draft.members - model.adults) .. " 孩子", 13, C.muted),
        UI.Panel {id = "opening-people-grid", gap = 14, flexShrink = 0, children = members},
        Skin.TextAction("查看全家亲缘 ›", function() app:OpenOpeningDetail("people") end, {id = "opening-family-detail", fontSize = 15}),
        Skin.TextAction("添一位族人", function() app:AddMember() end, {id = "opening-add-member", fontSize = 15}),
    }
end

local function relics(app, model)
    ---@type Widget[]
    local children = {heading("家传旧物", "选择 ›", function() app:BeginOpeningEdit("relics") end, "opening-edit-relics")}
    for _, info in ipairs(model.relics) do
        children[#children + 1] = UI.Panel {id = "opening-relic-" .. info.id, gap = 10, paddingBottom = 16, borderRadius = 0,
            borderBottomWidth = 1, borderBottomColor = C.rule, flexShrink = 0, pointerEvents = "box-only",
            onClick = function() app:OpenOpeningDetail("heirloom", info.id) end, children = {
                Skin.Image(Art.Relic(info.id), {width = "100%", height = 164}),
                text(info.name, 25, C.ink, {width = "100%", textAlign = "center"}),
                text(info.cost .. " 点 · 托付 " .. info.holder, 13, C.muted),
                text(info.effect, 15), text("查看来历与作用 ›", 14, C.muted),
            }}
    end
    if #model.relics == 0 then children[#children + 1] = text("本局未带入旧物，可从已解锁的旧物中选择。", 16, C.muted) end
    return children
end

local function forecast(app, model)
    local value = model.forecast
    if not value then return {text("请先修正开局安排。", 16, C.red)} end
    local function amount(label, number, unit)
        return UI.Panel {flex = 1, minWidth = 0, gap = 10, children = {
            text(label, 13, C.muted), text(signed(number) .. " " .. unit, 34, number < 0 and C.red or C.ink),
        }}
    end
    return {
        row({text("首年收支", 23), UI.Panel {flex = 1}, text("不含突发", 12, C.muted)}),
        text("按当前安排预计", 12, C.muted, {marginTop = 14}),
        row({amount("银两变化", value.netMoney, "两"), amount("粮食变化", value.netGrain, "石")}, {paddingVertical = 14}),
        Skin.Line(),
        Skin.LedgerRow {label = "年末现银", values = {{text = value.money, unit = "两"}}},
        Skin.LedgerRow {label = "年末存粮", values = {{text = value.grain, unit = "石"}}},
        text("年内事件与安排变化会影响实际结余。", 13, C.muted),
        Skin.TextAction("查看首年收支明细 ›", function() app:OpenOpeningDetail("ledger") end, {id = "opening-ledger-detail", fontSize = 16}),
    }
end

function OpeningTabs.Build(app, model)
    app.openingTab = app.openingTab or "overview"
    app.openingTabScroll = app.openingTabScroll or {}
    model.adults = 0
    for _, member in ipairs(app.draft.members) do if State.IsAdult(member) then model.adults = model.adults + 1 end end
    if app.openingTabsDraft ~= app.draft then
        app.openingTabsDraft, app.openingTabScroll = app.draft, {}
    end
    local selected = 0
    for index, tab in ipairs(tabs) do if tab.id == app.openingTab then selected = index end end
    assert(selected > 0, "开局标签未登记：" .. tostring(app.openingTab))
    local function select(id)
        if app.openingTab == id then return end
        app.openingTab = id
        app:Render()
    end
    local nav = UI.Panel {paddingHorizontal = 18, flexShrink = 0, children = {Skin.Tabs(tabs, app.openingTab, select)}}
    local dots = {}
    for i = 1, #tabs do dots[#dots + 1] = UI.Panel {width = i == selected and 12 or 4, height = 3, backgroundColor = i == selected and C.ink or C.rule} end
    local pager = UI.Panel {paddingHorizontal = 16, flexShrink = 0, children = {row({
        Skin.IconAction("back", function() select(tabs[selected - 1].id) end, {id = "opening-tabs-previous", disabled = selected == 1}),
        UI.Panel {flex = 1}, text(tabs[selected].label, 11, C.muted), UI.Row {width = 64, flexShrink = 0, gap = 5, alignItems = "center", justifyContent = "center", children = dots},
        text(numerals[selected] .. " / 六", 11, C.muted), UI.Panel {flex = 1},
        Skin.IconAction("chevron_right", function() select(tabs[selected + 1].id) end, {id = "opening-tabs-next", disabled = selected == #tabs}),
    }, {gap = 10})}}
    local builders = {overview = overview, family = family, estate = estate, people = people, relics = relics, forecast = forecast}
    local body = UI.Panel {id = "opening-tab-body", width = "100%", flexGrow = 1, flexBasis = 0, minHeight = 0,
        onSwipeLeft = function() if selected < #tabs then select(tabs[selected + 1].id) end end,
        onSwipeRight = function() if selected > 1 then select(tabs[selected - 1].id) end end}
    local issues = State.ValidateDraft(app.draft, app.profile, false)
    local id = app.openingTab
    local children = builders[id](app, model, select)
    if id == "overview" then
        if app.openingFeedback ~= "" then table.insert(children, 1, text(app.openingFeedback, 13, C.red)) end
        if #issues > 0 then table.insert(children, 1, text(table.concat(issues, "\n"), 13, C.red)) end
    end
    local panel = UI.ScrollView {id = "opening-scroll-" .. id, width = "100%", flexGrow = 1, flexBasis = 0, minHeight = 0,
        scrollX = false, showScrollbar = false, bounces = false,
        onScroll = function(_, _, y) app.openingTabScroll[id] = y end,
        children = {UI.Panel {id = "opening-content-" .. id, width = "100%", paddingHorizontal = 20,
            paddingVertical = id == "overview" and 0 or 16, gap = id == "overview" and 0 or 10, flexShrink = 0, children = children}}}
    panel:SetScrollDirect(0, app.openingTabScroll[id] or 0)
    body:AddChild(panel)
    local footer = UI.Panel {id = "opening-footer", paddingHorizontal = 20, paddingVertical = 8, gap = 5, flexShrink = 0,
        borderRadius = 0, borderTopWidth = 1, borderTopColor = C.rule, children = {
            entry("opening-points-detail", {text("开局点数 " .. State.TotalPoints(app.draft) .. " / " .. Data.LIMIT, 13, #issues > 0 and C.red or C.muted),
                UI.Panel {flex = 1}, text("明细 ›", 12, C.muted)}, function() app:OpenOpeningDetail("points") end, {minHeight = 30, borderBottomWidth = 0}),
            Skin.Button("就从这家开始  →", function() app:StartRun() end, {id = "opening-start", width = "100%", height = 50, fontSize = 19, disabled = #issues > 0}),
            row({Skin.TextAction("另择一家", function() app:ChangeHouse() end, {id = "opening-change-house", flex = 1, fontSize = 14}),
                app.houseUndo and Skin.TextAction("恢复上一家", function() app:UndoHouse() end, {id = "opening-undo-house", flex = 1, fontSize = 14}) or UI.Panel {width = 0},
                app.previousDraft and Skin.TextAction("回原家谱", function() app:CancelNewRun() end, {id = "opening-return-run", flex = 1, fontSize = 14}) or UI.Panel {width = 0}}, {gap = 6}),
        }}
    return Skin.NineSlice("paper_sheet.png", 24, {id = "opening-summary", width = "100%", height = "100%", overflow = "hidden",
        backgroundColor = C.paper, children = {
            Skin.Header {title = "开卷立家", subtitle = "凡世王朝 · " .. Data.WORLD_NAME, onBack = function() app:ReturnToCover() end, backText = "首页", backId = "opening-home"},
            nav, body, pager, footer,
        }})
end

return OpeningTabs
