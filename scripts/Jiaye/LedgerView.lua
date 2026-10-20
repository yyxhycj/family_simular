local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"
local RelicDefinitions = require "Jiaye.RelicDefinitions"

local LedgerView = {}
local C = V7.Colors
local transparent = { 0, 0, 0, 0 }
local paper = { 248, 243, 232, 255 }
local selected = { 242, 240, 228, 255 }
local line = { 220, 211, 191, 255 }

local function Text(value, size, color, props)
    props = props or {}
    props.fontSize, props.fontColor = size or 14, color or C.ink
    props.whiteSpace = props.whiteSpace or (props.flex and "normal" or "nowrap")
    props.lineHeight = props.lineHeight or 1.5
    return Visual.Text(tostring(value), props)
end

local function Signed(value)
    return (value > 0 and "+" or value < 0 and "−" or "") .. tostring(math.abs(value))
end

local function Tone(value)
    return value > 0 and C.primary or value < 0 and C.danger or C.secondary
end

local function Button(label, onClick, props)
    props = props or {}
    props.text, props.onClick = label, onClick
    props.height, props.minHeight, props.minWidth = props.height or 44, props.minHeight or 44, 0
    props.paddingHorizontal, props.paddingVertical = props.paddingHorizontal or 0, props.paddingVertical or 0
    props.fontSize, props.fontFamily = V7.Font(props.fontSize or 14), "serif"
    props.textColor = props.textColor or C.primary
    props.backgroundColor = props.backgroundColor or transparent
    props.hoverBackgroundColor, props.pressedBackgroundColor = { 53, 92, 73, 12 }, { 53, 92, 73, 24 }
    props.disabledBackgroundColor, props.disabledTextColor = transparent, C.disabledInk
    props.borderWidth, props.borderRadius = props.borderWidth or 0, 0
    props.boxShadow, props.hoverBoxShadow, props.pressedBoxShadow = false, false, false
    return UI.Button(props)
end

local function Row(label, value, props)
    props = props or {}
    local valueColor = props.valueColor or C.ink
    props.valueColor = nil
    props.flexDirection, props.alignItems, props.gap = "row", "center", 10
    props.children = {
        Text(label, 13, C.secondary, { flex = 1, minWidth = 0 }),
        Text(value, 14, valueColor, { textAlign = "right", flexShrink = 0 }),
    }
    return UI.Panel(props)
end

local function Disclosure(id, label, content)
    content:SetVisible(false)
    local indicator = Text("+", 19, C.gold)
    return UI.Panel { width = "100%", children = {
        Button(nil, function()
            local open = not content:IsVisible()
            content:SetVisible(open)
            indicator:SetText(open and "−" or "+")
        end, { id = id, width = "100%", flexDirection = "row", alignItems = "center", gap = 10,
            children = { Text(label, 12, C.secondary, { flex = 1, minWidth = 0 }), indicator } }),
        content,
    } }
end

local function BalanceCell(title, icon, amount, before, change, unit, divided)
    local direction = change > 0 and "增加 " or change < 0 and "减少 " or "不变 "
    return UI.Panel { flex = 1, minWidth = 0, gap = 4, paddingLeft = divided and 17 or 0,
        borderLeftWidth = divided and 1 or 0, borderLeftColor = line, children = {
            UI.Row { gap = 5, alignItems = "center", children = { Visual.Icon(icon, 15), Text(title, 13, C.secondary) } },
            UI.Row { alignItems = "baseline", gap = 5, children = {
                Text(amount, 43, C.ink, { fontFamily = "serif", lineHeight = 1.15 }), Text(unit, 13, C.ink),
            } },
            Text("年初 " .. tostring(before) .. " " .. unit, 12, C.secondary),
            Text("本年" .. direction .. tostring(math.abs(change)) .. " " .. unit, 12, Tone(change)),
        } }
end

local function OriginSourceText(source)
    local names = { seed = "留种增产", scroll = "旧卷借阅", study_referral = "求学引荐", work_referral = "谋生引荐" }
    local values = {}
    for _, item in ipairs({ { "learn", "学识", "" }, { "money", "银", " 两" }, { "grain", "粮", " 石" } }) do
        if (source[item[1]] or 0) ~= 0 then table.insert(values, item[2] .. " " .. Signed(source[item[1]]) .. item[3]) end
    end
    return (names[source.kind] or "背景加成") .. (#values > 0 and " · " .. table.concat(values, " · ") or "")
end

local function TransactionText(entry)
    local names = {
        event_fee = "事件费用", trade_capital_out = "交易本金投入", trade_capital_return = "交易本金回款",
        old_debt_recovery = "旧账回收", trade_profit = "交易净利润", event_wage = "事件报酬",
        deposit_out = "押金转出", deposit_return = "押金退回", deposit_forfeited = "押金损失",
        benefit_discount = "优惠减免", event_grain_out = "粮食支出", event_grain_in = "粮食收入",
        relic_action_cost = "行动费用", relic_principal_return = "本金返还", relic_project_profit = "项目报酬",
        relic_migration_discount = "迁居减免", relic_aid = "外部援助", relic_sale = "出售所得", relic_growth = "额外成长",
    }
    local label = names[entry.category] or "事务收支"
    if entry.category == "deposit_forfeited" then
        return label .. " " .. tostring(math.abs(entry.depositLoss or entry.deposit or entry.amount or 0)) .. " 两（由已付押金扣除）"
    end
    if entry.discount then return label .. " · 少付 " .. tostring(entry.discount) .. " 两" end
    return label .. " · 银 " .. Signed(entry.money or 0) .. " 两 · 粮 " .. Signed(entry.grain or 0) .. " 石"
        .. (entry.description and "\n" .. entry.description or "")
end

local function Overview(ledger, run)
    local netMoney = assert(ledger.netMoney, "年度账本缺少银钱净变。")
    local netGrain = assert(ledger.netGrain, "年度账本缺少粮食净变。")
    local foodStatus = ledger.foodSatisfied == false and "本年口粮不足"
        or (ledger.boughtGrain or 0) > 0 and "已购粮补足口粮" or "本年口粮充足"
    local children = { UI.Panel { id = "ledger-balances", width = "100%", gap = 15, padding = 16,
        backgroundColor = selected, borderWidth = 1, borderColor = { 155, 163, 137, 255 }, borderRadius = 0, children = {
            Row("年末家底", "本年结算后"),
            UI.Row { gap = 12, children = {
                BalanceCell("库银", "money", assert(ledger.money), assert(ledger.beforeMoney), netMoney, "两", false),
                BalanceCell("存粮", "grain", assert(ledger.grain), assert(ledger.beforeGrain), netGrain, "石", true),
            } },
            Text(ledger.resourcesExhausted and "家道散尽 · " .. foodStatus or foodStatus, 12,
                (ledger.foodSatisfied == false or ledger.resourcesExhausted) and C.danger or C.primary,
                { borderTopWidth = 1, borderTopColor = line, paddingTop = 10 }),
        } }, Text("银钱收支", 17, C.ink, { fontFamily = "serif", marginTop = 6 }) }
    local items = {
        { "谋生所得", ledger.income or 0 }, { "信物年度收益", ledger.relicIncome or 0 },
        { "背景年度收益", ledger.originIncome or 0 }, { "亲家年度往来", (ledger.marriage or {}).money or 0 }, { "产业收入", ledger.industryIncome or 0 },
        { "售粮所得", ledger.saleIncome or 0 }, { "族人培养", -(ledger.training or 0) },
        { "全家生活", -(ledger.livingExpense or 0) }, { "补购口粮", -(ledger.foodCost or 0) },
    }
    local total = 0
    for _, item in ipairs(items) do total = total + item[2] end
    if total ~= netMoney then table.insert(items, { "其他年度结算", netMoney - total }) end
    local lines, other = {}, {}
    for _, item in ipairs(items) do
        local amount = item[2]
        if amount == 0 then table.insert(other, Row(item[1], "0 两")) else
            table.insert(lines, UI.Row { width = "100%", alignItems = "center", gap = 9, paddingVertical = 12,
                borderBottomWidth = 1, borderBottomColor = line, children = {
                    Text(amount > 0 and "入" or "出", 12, Tone(amount), { width = 22, textAlign = "center", paddingVertical = 2,
                        backgroundColor = amount > 0 and C.selected or { 239, 225, 214, 255 } }),
                    Text(item[1], 15, C.ink, { flex = 1, minWidth = 0 }),
                    Text(Signed(amount) .. " 两", 17, Tone(amount), { flexShrink = 0 }),
                } })
        end
    end
    if #lines == 0 then table.insert(lines, Text("本年银钱无收支。", 14, C.secondary)) end
    table.insert(lines, Row(netMoney < 0 and "本年净支出" or netMoney > 0 and "本年净收入" or "本年收支相抵",
        tostring(math.abs(netMoney)) .. " 两", { paddingVertical = 12, valueColor = Tone(netMoney) }))
    table.insert(children, UI.Panel { id = "ledger-money-lines", width = "100%", children = lines })
    local grainCells = {}
    for _, item in ipairs({ { "全年需粮", ledger.foodNeed or 0 },
        { (ledger.foodShortfall or 0) > 0 and "需补口粮" or "粮食缺口", ledger.foodShortfall or 0 },
        { netGrain < 0 and "存粮净减" or netGrain > 0 and "存粮净增" or "存粮净变", math.abs(netGrain) } }) do
        table.insert(grainCells, UI.Panel { flex = 1, minWidth = 0, gap = 7, alignItems = "center", children = {
            Text(item[1], 12, C.secondary), Text(tostring(item[2]) .. " 石", 17, C.ink),
        } })
    end
    table.insert(children, UI.Row { id = "ledger-grain", paddingVertical = 15, borderTopWidth = 1, borderTopColor = line,
        borderBottomWidth = 1, borderBottomColor = line, children = grainCells })
    for _, item in ipairs({ { "田产收粮", ledger.landGrain or 0, " 石" }, { "补购口粮", ledger.boughtGrain or 0, " 石" },
        { "售出粮食", ledger.grainSold or 0, " 石" }, { "背景粮食加成", ledger.originGrain or 0, " 石" },
        { "背景学识加成", ledger.originGrowth or 0, "" } }) do
        table.insert(other, Row(item[1], tostring(item[2]) .. item[3]))
    end
    for _, source in ipairs(ledger.originGrainSources or {}) do table.insert(other, Text(OriginSourceText(source), 13, C.secondary)) end
    for _, source in ipairs((ledger.marriage or {}).sources or {}) do
        local value = source.stat and (Data.FocusNames[source.stat] .. "+" .. source.growth) or source.grain and (Signed(source.grain) .. "石") or (Signed(source.money or 0) .. "两")
        table.insert(other, Text(source.name .. " · " .. value, 13, C.primary, { whiteSpace = "normal" }))
    end
    if (ledger.marriage or {}).thrift == 2 then table.insert(other, Text("持家有方 · 生活费减2两", 13, C.primary)) end
    table.insert(children, Disclosure("ledger-other", "其他分项与年度加成", UI.Panel { gap = 9, paddingBottom = 12, children = other }))
    local transactions = {}
    for _, entry in ipairs(ledger.relicTransactions or {}) do table.insert(transactions, Text(TransactionText(entry), 13, C.secondary, { whiteSpace = "normal" })) end
    local originTransactions = ledger.originTransactions
    if type(originTransactions) ~= "table" then
        originTransactions = {}
        for _, entry in ipairs(run.originTransactions or {}) do
            if ledger.yearIndex ~= nil and entry.yearIndex == ledger.yearIndex then table.insert(originTransactions, entry) end
        end
    end
    for _, entry in ipairs(originTransactions) do table.insert(transactions, Text(TransactionText(entry), 13, C.secondary, { whiteSpace = "normal" })) end
    if #transactions > 0 then
        table.insert(children, Disclosure("ledger-transactions", "信物与背景事务记录 · " .. #transactions .. " 笔",
            UI.Panel { gap = 12, paddingBottom = 12, children = transactions }))
    end
    return UI.Panel { id = "ledger-overview", width = "100%", gap = 14, children = children }
end

local function GrowthText(row)
    local growth = row.growth or {}
    if row.executed == false then return "本年未执行" end
    if growth.stat and growth.stat ~= "health" then
        return assert(Data.FocusNames[growth.stat], "账本成长属性未登记。") .. " " .. Signed(growth.amount or 0)
    end
    if (growth.health or 0) ~= 0 then return "体魄 " .. Signed(growth.health) end
    return "年度安排已执行"
end

local function MemberDetails(row)
    if row.executed == false then return UI.Panel { paddingBottom = 14, children = { Text(row.reason or "条件未满足。", 13, C.danger, { whiteSpace = "normal" }) } } end
    local children, growth = {}, row.growth or {}
    if growth.stat and growth.stat ~= "health" then
        table.insert(children, Text("成长来源 · " .. GrowthText(row), 12, C.secondary))
        local sources = {}
        for index, item in ipairs({ { "基础", row.baseGrowth or 0 }, { "偏向", row.focusGrowth or 0 },
            { "信物", row.relicGrowth or 0 }, { "家风", row.habitGrowth or 0 }, { "背景", row.originGrowth or 0 } }) do
            table.insert(sources, UI.Panel { flex = 1, minWidth = 0, paddingVertical = 8, alignItems = "center", gap = 5,
                backgroundColor = index == 1 and C.selected or transparent, borderWidth = 1, borderColor = line, borderRadius = 0,
                children = { Text(item[1], 11, C.secondary), Text(Signed(item[2]), 14, Tone(item[2])) } })
        end
        table.insert(children, UI.Row { gap = 4, children = sources })
    elseif (growth.health or 0) ~= 0 then table.insert(children, Text(GrowthText(row), 14, Tone(growth.health))) end
    table.insert(children, Row("职业收支", Signed((row.money or 0) - (row.relicIncome or 0) - (row.originIncome or 0) - (row.marriageIncome or 0)) .. " 两"))
    if (row.marriageIncome or 0) ~= 0 then table.insert(children, Row("亲家资助", Signed(row.marriageIncome) .. " 两")) end
    if (row.marriageGrowth or 0) ~= 0 then table.insert(children, Row("亲家传习成长", "+" .. row.marriageGrowth)) end
    table.insert(children, Row("信物收益", Signed(row.relicIncome or 0) .. " 两"))
    table.insert(children, Row("背景收益", Signed(row.originIncome or 0) .. " 两"))
    if (row.grain or 0) ~= 0 then table.insert(children, Row("收获粮食", Signed(row.grain) .. " 石")) end
    if #(row.relicSources or {}) > 0 then table.insert(children, Text("信物来源", 12, C.secondary, { marginTop = 5 })) end
    for _, source in ipairs(row.relicSources or {}) do
        local form = assert(RelicDefinitions.Form(source.formId), "账本信物形态未登记。")
        table.insert(children, Text(form.name, 14, C.ink))
    end
    for _, source in ipairs(row.originSources or {}) do table.insert(children, Text(OriginSourceText(source), 13, C.secondary)) end
    return UI.Panel { gap = 9, paddingBottom = 16, children = children }
end

local function Members(ledger, state)
    local rows = ledger.members or {}
    local children = { Row("族人年度记", tostring(#rows) .. " 人 · 点按展开") }
    for index, row in ipairs(rows) do
        local key = tostring(ledger.id or ledger.year) .. ":" .. tostring(row.memberId or index)
        local open = state.expanded[key] == true
        local detail = MemberDetails(row)
        local arrow = UI.Panel { width = 7, height = 7, flexShrink = 0, pointerEvents = "none",
            rotate = open and 45 or -45, borderRadius = 0,
            borderRightWidth = 1, borderBottomWidth = 1, borderRightColor = C.gold, borderBottomColor = C.gold }
        detail:SetVisible(open)
        local card = UI.Panel { width = "100%", borderBottomWidth = 1, borderBottomColor = line, borderRadius = 0,
            backgroundColor = open and selected or transparent }
        local note = GrowthText(row)
        if #(row.relicSources or {}) > 0 then note = note .. " · " .. #row.relicSources .. " 件信物" end
        local name = tostring(row.name)
        card:AddChild(Button(nil, function()
            local nextOpen = not detail:IsVisible()
            state.expanded[key] = nextOpen
            detail:SetVisible(nextOpen)
            arrow:SetStyle({ rotate = nextOpen and 45 or -45 })
            card:SetStyle({ backgroundColor = nextOpen and selected or transparent })
        end, { id = "ledger-member-" .. tostring(row.memberId or index), width = "100%", height = "auto", minHeight = 76,
            paddingVertical = 12, flexDirection = "row", alignItems = "center", gap = 10, children = {
                UI.Panel { width = 32, height = 38, alignItems = "center", justifyContent = "center", pointerEvents = "none",
                    backgroundColor = { 233, 231, 217, 255 }, borderWidth = 1, borderColor = line, borderRadius = 0,
                    children = { Text(name:sub(utf8.offset(name, -1)), 19, C.primary, { fontFamily = "serif" }) } },
                UI.Panel { flex = 1, minWidth = 0, gap = 4, pointerEvents = "none", children = {
                    Text(name, 17, C.ink, { fontFamily = "serif", fontWeight = "bold" }),
                    Text(tostring(row.job), 12, C.secondary, { whiteSpace = "normal" }),
                    Text(note, 12, row.executed == false and C.danger or C.primary, { whiteSpace = "normal" }),
                } },
                Text(Signed(row.money or 0) .. " 两", 16, Tone(row.money or 0), { flexShrink = 0 }), arrow,
            } }))
        card:AddChild(detail)
        table.insert(children, card)
    end
    if #rows == 0 then table.insert(children, Text("这一年的账本没有成员分项记录。", 14, C.secondary)) end
    table.insert(children, Row("谋生所得", Signed(ledger.income or 0) .. " 两", { paddingTop = 10 }))
    table.insert(children, Row("培养支出", Signed(-(ledger.training or 0)) .. " 两"))
    table.insert(children, Text("成员收支按个人安排记载。全家生活用度见「收支总览」。", 12, C.secondary, { marginTop = 8, whiteSpace = "normal" }))
    return UI.Panel { id = "ledger-members", width = "100%", gap = 8, children = children }
end

function LedgerView.Build(app)
    local ledgers = app.run.annualLedgers or {}
    if #ledgers == 0 then return UI.Panel { padding = 22, gap = 12, backgroundColor = paper, borderWidth = 1, borderColor = line,
        children = { Text("年度账本", 22, C.ink, { fontFamily = "serif" }),
            Text("推进第一年后，这里会记下银粮结余、收支分项与族人年度经历。", 14, C.secondary, { whiteSpace = "normal" }) } } end
    if not app.ledgerBrowser or app.ledgerBrowser.run ~= app.run then
        app.ledgerBrowser = { run = app.run, index = 1, tab = "overview", expanded = {}, latest = ledgers[1].id }
    end
    local state = app.ledgerBrowser
    if state.latest ~= ledgers[1].id then state.index, state.latest = 1, ledgers[1].id end
    local book = UI.Panel { id = "annual-ledger", width = "100%", gap = 18, padding = 19, backgroundColor = paper,
        backgroundImage = V7.Images.paperFiber, backgroundImageOpacity = 0.23, backgroundFit = "cover",
        borderWidth = 1, borderColor = line, borderRadius = 0 }
    local function render()
        book:ClearChildren()
        state.index = math.max(1, math.min(state.index, #ledgers))
        local ledger = ledgers[state.index]
        book:AddChild(UI.Row { gap = 6, alignItems = "center", children = {
            Button("‹ 新一年", function() state.index = state.index - 1; render() end,
                { id = "ledger-newer", flex = 1, disabled = state.index == 1 }),
            Text(tostring(state.index) .. " / " .. #ledgers, 12, C.secondary, { width = 48, textAlign = "center" }),
            Button("旧一年 ›", function() state.index = state.index + 1; render() end,
                { id = "ledger-older", flex = 1, disabled = state.index == #ledgers }),
        } })
        book:AddChild(UI.Row { gap = 7, alignItems = "baseline", children = {
            Text("大晟历", 13, C.ink), Text(ledger.year, 39, C.ink, { id = "ledger-year", fontFamily = "serif", lineHeight = 1.1 }),
            Text("年", 14, C.ink), UI.Panel { flex = 1 },
            Text("岁末结算", 11, C.secondary, { padding = 6, borderWidth = 1, borderColor = line }),
        } })
        local overview, members = Overview(ledger, app.run), Members(ledger, state)
        overview:SetVisible(state.tab == "overview")
        members:SetVisible(state.tab == "members")
        local tabs = {}
        local function select(tab)
            state.tab = tab
            overview:SetVisible(tab == "overview")
            members:SetVisible(tab == "members")
            for id, button in pairs(tabs) do button:SetStyle({ textColor = id == tab and C.primary or C.secondary,
                borderBottomWidth = id == tab and 3 or 0, borderBottomColor = C.primary }) end
        end
        local tabRow = UI.Row { gap = 22, borderBottomWidth = 1, borderBottomColor = line }
        for _, item in ipairs({ { "overview", "收支总览" }, { "members", "成员明细" } }) do
            local id = item[1]
            local button = Button(item[2], function() select(id) end, { id = "ledger-tab-" .. id, flex = 1, fontSize = 16,
                textColor = state.tab == id and C.primary or C.secondary,
                borderBottomWidth = state.tab == id and 3 or 0, borderBottomColor = C.primary })
            tabs[id] = button
            tabRow:AddChild(button)
        end
        overview:AddChild(Button("查阅成员细账  →", function() select("members") end,
            { id = "ledger-view-members", width = "100%", height = 47, borderWidth = 1, borderColor = C.primary }))
        book:AddChild(tabRow)
        book:AddChild(overview)
        book:AddChild(members)
        local family = app.run.openingSnapshot and app.run.openingSnapshot.family or app.run.family
        book:AddChild(Row(tostring(family or "家族") .. "氏家账", tostring(ledger.year) .. " 年", {
            borderTopWidth = 1, borderTopColor = line, paddingTop = 13 }))
    end
    render()
    return book
end

return LedgerView
