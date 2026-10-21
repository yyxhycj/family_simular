local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"
local RelicDefinitions = require "Jiaye.RelicDefinitions"
local Economy = require "Jiaye.Economy"
local ModalLayout = require "Jiaye.ModalLayout"

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

local function Calculation(label, value, formula, id)
    return UI.Panel { id = id, width = "100%", gap = 4, paddingVertical = 6, children = {
        Row(label, value),
        Text(formula, 12, C.secondary, { width = "100%", whiteSpace = "normal" }),
    } }
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

local function BalanceCell(title, icon, amount, before, change, unit, divided, preview)
    local direction = change > 0 and "增加 " or change < 0 and "减少 " or "不变 "
    return UI.Panel { flex = 1, minWidth = 0, gap = 4, paddingLeft = divided and 17 or 0,
        borderLeftWidth = divided and 1 or 0, borderLeftColor = line, children = {
            UI.Row { gap = 5, alignItems = "center", children = { Visual.Icon(icon, 15), Text(title, 13, C.secondary) } },
            UI.Row { alignItems = "baseline", gap = 5, children = {
                Text(amount, 43, C.ink, { fontFamily = "serif", lineHeight = 1.15 }), Text(unit, 13, C.ink),
            } },
            Text((preview and "当前 " or "年初 ") .. tostring(before) .. " " .. unit, 12, C.secondary),
            Text((preview and "预计" or "本年") .. direction .. tostring(math.abs(change)) .. " " .. unit, 12, Tone(change)),
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

local function Overview(ledger, run, preview)
    local netMoney = assert(ledger.netMoney, "年度账本缺少银钱净变。")
    local netGrain = assert(ledger.netGrain, "年度账本缺少粮食净变。")
    local foodStatus = ledger.foodSatisfied == false and "本年口粮不足"
        or (ledger.boughtGrain or 0) > 0 and "已购粮补足口粮" or "本年口粮充足"
    if preview then
        foodStatus = ledger.foodSatisfied == false and "预计口粮不足"
            or (ledger.boughtGrain or 0) > 0 and "预计购粮补足口粮" or "预计口粮充足"
    end
    local children = { UI.Panel { id = "ledger-balances", width = "100%", gap = 15, padding = 16,
        backgroundColor = selected, borderWidth = 1, borderColor = { 155, 163, 137, 255 }, borderRadius = 0, children = {
            Row(preview and "预计年末家底" or "年末家底", preview and "按当前安排" or "本年结算后"),
            UI.Row { gap = 12, children = {
                BalanceCell("库银", "money", assert(ledger.money), assert(ledger.beforeMoney), netMoney, "两", false, preview),
                BalanceCell("存粮", "grain", assert(ledger.grain), assert(ledger.beforeGrain), netGrain, "石", true, preview),
            } },
            Text(ledger.resourcesExhausted and (preview and "预计钱粮耗尽 · " or "家道散尽 · ") .. foodStatus or foodStatus, 12,
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
    if #lines == 0 then table.insert(lines, Text(preview and "预计银钱无收支。" or "本年银钱无收支。", 14, C.secondary)) end
    local periodLabel = preview and "预计" or "本年"
    table.insert(lines, Row(periodLabel .. (netMoney < 0 and "净支出" or netMoney > 0 and "净收入" or "收支相抵"),
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
    if #transactions > 0 and not preview then
        table.insert(children, Disclosure("ledger-transactions", "信物与背景事务记录 · " .. #transactions .. " 笔",
            UI.Panel { gap = 12, paddingBottom = 12, children = transactions }))
    end
    return UI.Panel { id = "ledger-overview", width = "100%", gap = 14, children = children }
end

local function GrowthText(row, preview)
    local growth = row.growth or {}
    if row.executed == false then return preview and "预计无法执行" or "本年未执行" end
    if growth.stat and growth.stat ~= "health" then
        return assert(Data.FocusNames[growth.stat], "账本成长属性未登记。") .. " " .. Signed(growth.amount or 0)
    end
    if (growth.health or 0) ~= 0 then return "体魄 " .. Signed(growth.health) end
    return preview and "预计可执行" or "年度安排已执行"
end

local function MemberDetails(row, preview)
    if row.executed == false then return UI.Panel { paddingBottom = 14, children = { Text(row.reason or "条件未满足。", 13, C.danger, { whiteSpace = "normal" }) } } end
    local children, growth = {}, row.growth or {}
    if growth.stat and growth.stat ~= "health" then
        table.insert(children, Text("成长来源 · " .. GrowthText(row, preview), 12, C.secondary))
        local sources = {}
        for index, item in ipairs({ { "基础", row.baseGrowth or 0 }, { "偏向", row.focusGrowth or 0 },
            { "信物", row.relicGrowth or 0 }, { "家风", row.habitGrowth or 0 }, { "背景", row.originGrowth or 0 } }) do
            table.insert(sources, UI.Panel { flex = 1, minWidth = 0, paddingVertical = 8, alignItems = "center", gap = 5,
                backgroundColor = index == 1 and C.selected or transparent, borderWidth = 1, borderColor = line, borderRadius = 0,
                children = { Text(item[1], 11, C.secondary), Text(Signed(item[2]), 14, Tone(item[2])) } })
        end
        table.insert(children, UI.Row { gap = 4, children = sources })
    elseif (growth.health or 0) ~= 0 then table.insert(children, Text(GrowthText(row, preview), 14, Tone(growth.health))) end
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

local function Members(ledger, state, preview)
    local rows = ledger.members or {}
    local children = { Row(preview and "族人下年安排" or "族人年度记", tostring(#rows) .. " 人 · 点按展开") }
    for index, row in ipairs(rows) do
        local key = tostring(ledger.id or ledger.year) .. ":" .. tostring(row.memberId or index)
        local open = state.expanded[key] == true
        local detail = MemberDetails(row, preview)
        local arrow = UI.Panel { width = 7, height = 7, flexShrink = 0, pointerEvents = "none",
            rotate = open and 45 or -45, borderRadius = 0,
            borderRightWidth = 1, borderBottomWidth = 1, borderRightColor = C.gold, borderBottomColor = C.gold }
        detail:SetVisible(open)
        local card = UI.Panel { width = "100%", borderBottomWidth = 1, borderBottomColor = line, borderRadius = 0,
            backgroundColor = open and selected or transparent }
        local note = GrowthText(row, preview)
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
    table.insert(children, Text(preview and "成员收支按当前安排预计，培养费已计入个人收支。" or "成员收支按个人安排记载。全家生活用度见「收支总览」。", 12, C.secondary, { marginTop = 8, whiteSpace = "normal" }))
    return UI.Panel { id = "ledger-members", width = "100%", gap = 8, children = children }
end

function LedgerView.OpenForecast(app)
    local run = app.run
    local ledger = Economy.Preview(run)
    local costs = assert(ledger.livingCosts, "预计收支缺少生活用度明细。")
    local function Number(value) return string.format("%g", value) end
    local household = {
        Calculation("住房维护 · " .. costs.home, costs.upkeep .. " 两", "每年固定维护费 " .. costs.upkeep .. " 两。"),
        Text("在家族人 · 每人年度生活费", 12, C.secondary),
    }
    for _, member in ipairs(costs.members) do
        table.insert(household, Row(member.name .. " · " .. member.age .. " 岁 · " .. (member.adult and "成年" or "未成年"), member.expense .. " 两"))
    end
    table.insert(household, Calculation("基础生活费", costs.baseExpense .. " 两",
        "住房 " .. costs.upkeep .. " + 成年 " .. costs.adults .. " 人 × 4 + 未成年 " .. costs.children .. " 人 × 2 = " .. costs.baseExpense .. " 两。",
        "forecast-base-expense"))
    table.insert(household, Row("时局 · " .. costs.period, "× " .. Number(costs.periodMultiplier)))
    table.insert(household, Row("落脚处 · " .. costs.place, "× " .. Number(costs.placeMultiplier)))
    table.insert(household, Calculation("物价调整后", costs.adjustedExpense .. " 两",
        costs.baseExpense .. " × " .. Number(costs.periodMultiplier) .. " × " .. Number(costs.placeMultiplier)
            .. "，向下取整 = " .. costs.adjustedExpense .. " 两。", "forecast-price-adjustment"))
    table.insert(household, Calculation("料理家事减免", Signed(-costs.careDiscount) .. " 两",
        (#costs.carers > 0 and table.concat(costs.carers, "、") or "当前无人料理家事") .. "；每人减 3 两。"
            .. costs.adjustedExpense .. " − " .. #costs.carers .. " × 3，最低为 0，剩 " .. costs.afterCare .. " 两。",
        "forecast-care-discount"))
    table.insert(household, Calculation("节用惜物家风", Signed(-costs.frugalDiscount) .. " 两",
        costs.frugalMultiplier < 1 and (costs.afterCare .. " × 0.9，向下取整 = " .. costs.afterFrugal .. " 两。")
            or "当前家风无节俭减免。", "forecast-frugal-discount"))
    table.insert(household, Calculation("持家有方减免", Signed(-costs.marriageDiscount) .. " 两",
        costs.marriageThrift > 0 and ("持家传习生效；" .. costs.afterFrugal .. " − " .. costs.marriageThrift
            .. "，最低为 0 = " .. ledger.livingExpense .. " 两。") or "当前无持家传习减免。", "forecast-marriage-discount"))
    table.insert(household, Calculation("生活费合计", ledger.livingExpense .. " 两",
        costs.adjustedExpense .. " − 持家 " .. costs.careDiscount .. " − 节俭 " .. costs.frugalDiscount
            .. " − 传习 " .. costs.marriageDiscount .. " = " .. ledger.livingExpense .. " 两。", "forecast-living-total"))

    local food = {
        Text("按在家且在世的族人计粮。年满 " .. Data.AgeRules.adult .. " 岁，每年 2 石；未成年每年 1 石。", 12, C.secondary,
            { width = "100%", whiteSpace = "normal" }),
    }
    for _, member in ipairs(costs.members) do
        table.insert(food, Row(member.name .. " · " .. member.age .. " 岁", member.food .. " 石"))
    end
    table.insert(food, Calculation("全年口粮", ledger.foodNeed .. " 石",
        "成年 " .. costs.adults .. " 人 × 2 + 未成年 " .. costs.children .. " 人 × 1 = " .. ledger.foodNeed .. " 石。", "forecast-food-total"))

    local training, trainingParts = {}, {}
    for _, member in ipairs(ledger.members) do
        local payment = member.paymentCalculation
        if payment then
            local formula = "基础费 " .. math.abs(payment.base) .. " × 时局系数 " .. Number(payment.periodMultiplier)
                .. "，向上取整 = " .. math.abs(payment.afterPeriod) .. "；再 × 地域系数 " .. Number(payment.placeMultiplier)
                .. "，向上取整 = " .. member.requiredPayment .. " 两。"
            if not member.executed then formula = formula .. "\n" .. member.reason end
            table.insert(training, Calculation(member.name .. " · " .. member.job, member.paid .. " 两", formula))
            table.insert(trainingParts, tostring(member.paid))
        end
    end
    table.insert(training, Calculation("培养费合计", ledger.training .. " 两",
        #trainingParts > 0 and (table.concat(trainingParts, " + ") .. " = " .. ledger.training .. " 两。") or "当前安排无培养费用。",
        "forecast-training-total"))
    local memberGrain = 0
    for _, member in ipairs(ledger.members) do memberGrain = memberGrain + (member.grain or 0) end
    local marriageGrain = (ledger.marriage or {}).grain or 0
    local consumed = ledger.beforeGrain + memberGrain + (ledger.landGrain or 0) + (ledger.originGrain or 0)
        + marriageGrain + ledger.boughtGrain - ledger.grainSold - ledger.grain
    local grain = {}
    for _, item in ipairs({ { "当前存粮", ledger.beforeGrain }, { "族人耕作", memberGrain }, { "田产收粮", ledger.landGrain or 0 },
        { "背景粮食加成", ledger.originGrain or 0 }, { "亲家粮食往来", marriageGrain }, { "补购口粮", ledger.boughtGrain },
        { "口粮消耗", -consumed }, { "售出粮食", -ledger.grainSold }, { "预计余粮", ledger.grain } }) do
        table.insert(grain, Row(item[1], tostring(item[2]) .. " 石"))
    end
    table.insert(food, Calculation("结算可用粮", ledger.foodAvailable .. " 石",
        "现粮 " .. ledger.beforeGrain .. " + 耕作 " .. memberGrain .. " + 田产 " .. (ledger.landGrain or 0)
            .. " + 背景 " .. (ledger.originGrain or 0) .. " + 亲家往来 " .. marriageGrain .. " = " .. ledger.foodAvailable .. " 石。"))
    table.insert(food, Calculation("需补口粮", ledger.foodShortfall .. " 石",
        ledger.foodNeed .. " − " .. ledger.foodAvailable .. "，最低为 0 = " .. ledger.foodShortfall .. " 石。"))
    table.insert(food, Calculation("补购口粮费用", ledger.foodCost .. " 两",
        ledger.foodShortfall > 0 and ("缺粮 " .. ledger.foodShortfall .. " 石 × " .. costs.period .. "粮价 " .. ledger.foodBasePrice
            .. " 两/石 × 地域系数 " .. Number(ledger.foodPriceMultiplier) .. "，向上取整需 " .. ledger.foodPurchaseQuote .. " 两。"
            .. "生活费扣除后可用银 " .. ledger.foodMoneyAvailable .. " 两。") or "预计收粮足够全年口粮，无需补购。", "forecast-food-cost"))
    if not ledger.foodSatisfied then
        table.insert(food, Text("银钱不足，补购未执行，补粮费为 0 两；尚缺 " .. tostring(ledger.foodNeed - consumed)
            .. " 石口粮，结算时全家体魄各减 12。", 13, C.danger, { width = "100%", whiteSpace = "normal" }))
    end
    if ledger.grainSold > 0 then
        table.insert(grain, Calculation("售粮补开支", ledger.saleIncome .. " 两",
            "口粮扣除后仍有银钱缺口，售出 " .. ledger.grainSold .. " 石 × " .. ledger.foodBasePrice .. " 两/石 = " .. ledger.saleIncome .. " 两。"))
    end
    local totalExpense = ledger.livingExpense + ledger.training + ledger.foodCost
    local modal = ModalLayout.New("下年收支明细", { id = "annual-forecast-detail", sheet = "full", closeOnOverlay = true })
    modal:AddContent(ModalLayout.Scroll(UI.Panel { id = "forecast-content", width = "100%", gap = 16, paddingBottom = 14, children = {
        Text(Data.WORLD_NAME .. "历 " .. tostring(run.calendar) .. " 年 · 按当前安排预计", 13, C.secondary, { whiteSpace = "normal" }),
        UI.Panel { padding = 14, gap = 8, backgroundColor = selected, borderWidth = 1, borderColor = line, children = {
            Row("全年生活费", ledger.livingExpense .. " 两", { valueColor = C.primary }),
            Row("全年口粮需求", ledger.foodNeed .. " 石", { valueColor = C.primary }),
        } },
        Text("生活费怎么算", 20, C.ink, { fontFamily = "serif" }),
        UI.Panel { id = "forecast-household", gap = 9, padding = 14, backgroundColor = paper, borderWidth = 1, borderColor = line, children = household },
        Text("口粮与补购怎么算", 20, C.ink, { fontFamily = "serif" }),
        UI.Panel { id = "forecast-food", gap = 9, children = food },
        Text("族人培养费用", 20, C.ink, { fontFamily = "serif" }),
        UI.Panel { id = "forecast-training", gap = 9, children = training },
        Calculation("年度银钱支出合计", totalExpense .. " 两", "生活费 " .. ledger.livingExpense .. " + 培养费 "
            .. ledger.training .. " + 补粮费 " .. ledger.foodCost .. " = " .. totalExpense .. " 两。", "forecast-expense-total"),
        Text("粮食收支明细", 20, C.ink, { fontFamily = "serif" }),
        UI.Panel { id = "forecast-grain-lines", gap = 9, children = grain },
        Overview(ledger, run, true),
        Disclosure("forecast-member-details", "族人安排与预计收支 · " .. tostring(#ledger.members) .. " 人", Members(ledger, { expanded = {} }, true)),
        Text("调整族人安排或家业后，重新打开可查看更新后的预计。接事件、置业等即时费用在操作时支付；年度事件与后续变化以推进后的实际结算为准。", 12, C.secondary,
            { id = "forecast-note", width = "100%", whiteSpace = "normal" }),
    } }, { id = "forecast-scroll" }))
    modal:Open()
    return modal
end

function LedgerView.Open(app, ledgerId)
    local ledgers = app.run.annualLedgers
    ---@type integer?
    local index
    for position, ledger in ipairs(ledgers) do if ledger.id == ledgerId then index = position; break end end
    assert(index, "找不到这年的账本。")
    app.ledgerBrowser = { run = app.run, index = index, tab = "overview", expanded = {}, latest = ledgers[1].id }
    local modal = ModalLayout.New("年度账本", { id = "ledger-detail", sheet = "full" })
    modal:AddContent(ModalLayout.Scroll(LedgerView.Build(app)))
    modal:Open()
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
