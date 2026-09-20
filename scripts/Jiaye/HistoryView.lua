local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"

local HistoryView = {}

local C = V7.Colors

local function Text(value, props)
    props = props or {}
    props.fontSize = math.max(15, props.fontSize or V7.Tokens.body)
    return Visual.Text(value, props)
end

local function Button(value, onClick, props)
    props = props or {}
    props.height = math.max(44, props.height or V7.Tokens.buttonHeight)
    props.fontSize = math.max(15, props.fontSize or V7.Tokens.buttonText)
    props.role = props.role or (props.selected and "primary" or "secondary")
    return Visual.Button(value, onClick, props)
end

local function Card(children, props)
    return Visual.Card(children, props)
end

local function TableValue(value)
    return type(value) == "table" and value or {}
end

local function ProgressText(item)
    local mark = item[6] == "at_most" and "≤" or "/"
    return item[1] .. "（" .. tostring(item[4] or "当前") .. "） " .. tostring(item[2]) .. mark .. tostring(item[3])
end

local function EndingEvidenceText(item)
    local comparison = item.comparison == "at_most" and "≤" or (item.comparison == "equal" and "=" or "/")
    return tostring(item.label) .. "：" .. tostring(item.current) .. comparison .. tostring(item.required) .. " · " .. tostring(item.source and item.source.source or "家史")
end

local function MemberButton(app, memberId, label)
    local member = State.FindMember(app.run.members, memberId)
    if not member then return Text(label or "人物记录缺失", { fontSize = 13, fontColor = C.secondary }) end
    return Button(label or member.name, function() app:OpenRunMember(member.id) end, { height = 44, fontSize = 13 })
end

local function Pager(app, key, count, pageSize)
    app.historyPages = app.historyPages or {}
    local pageCount = math.max(1, math.ceil(count / pageSize))
    local page = math.max(1, math.min(app.historyPages[key] or 1, pageCount))
    app.historyPages[key] = page
    local function turn(nextPage)
        app.historyPages[key] = math.max(1, math.min(nextPage, pageCount))
        app:Render()
    end
    return page, pageCount, UI.Row { gap = 6, children = {
        Button("最新", function() turn(1) end, { flex = 1, disabled = page == 1 }),
        Button("上一页", function() turn(page - 1) end, { flex = 1, disabled = page == 1 }),
        Text(tostring(page) .. " / " .. tostring(pageCount), { flex = 1, textAlign = "center", fontSize = 14, fontColor = C.secondary }),
        Button("下一页", function() turn(page + 1) end, { flex = 1, disabled = page == pageCount }),
        Button("最早", function() turn(pageCount) end, { flex = 1, disabled = page == pageCount }),
    } }
end

local function PagedCards(app, key, items, pageSize, title, emptyText, renderItem)
    local page, pageCount, pager = Pager(app, key, #items, pageSize)
    local cards = {}
    local first = (page - 1) * pageSize + 1
    local last = math.min(page * pageSize, #items)
    for index = first, last do table.insert(cards, renderItem(items[index])) end
    if #cards == 0 then table.insert(cards, Text(emptyText, { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal" })) end
    return Card({
        Text(title .. " · " .. tostring(#items) .. " 条 · 第 " .. tostring(page) .. "/" .. tostring(pageCount) .. " 页", { fontSize = 18, fontWeight = "bold" }),
        pager,
        UI.Panel { gap = 8, children = cards },
    })
end

local function BuildTerms(app)
    local calendar = TableValue(app.run.openingSnapshot).calendar or app.run.calendar
    return PagedCards(app, "terms", app.run.leaderTerms or {}, 6, "历任族长", "尚未记录任期。", function(term)
        local member = State.FindMember(app.run.members, term.memberId)
        local startYear = calendar + (term.startYear or 0)
        local endYear = term.endYear and (calendar + term.endYear) or "至今"
        return Card({
            Text((member and member.name or "未知族人") .. " · " .. tostring(startYear) .. "—" .. tostring(endYear), { fontSize = 16, fontWeight = "bold" }),
            Text("缘由：" .. tostring(term.reason or "未记录") .. " · " .. ((term.effective and "有效任期") or "任期尚未满一年"), { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" }),
            MemberButton(app, term.memberId, member and "查看此人生平" or "人物记录缺失"),
        })
    end)
end

local function BuildLedgers(app)
    return PagedCards(app, "ledgers", app.run.annualLedgers or {}, 4, "年度账本", "推进第一年后，这里会保留每一年的年初快照与结算分项。", function(ledger)
        local start = TableValue(ledger.yearStart)
        return Card({
            Text("大晟历 " .. tostring(ledger.year) .. " 年账本", { fontSize = 16, fontWeight = "bold" }),
            Text("年初：银 " .. tostring(start.money or ledger.beforeMoney or 0) .. " 两 · 粮 " .. tostring(start.grain or ledger.beforeGrain or 0) .. " 石\n收入 " .. tostring(ledger.income or 0) .. " 两 · 培养 " .. tostring(ledger.training or 0) .. " 两 · 产业 " .. tostring(ledger.industryIncome or 0) .. " 两 · 生活 " .. tostring(ledger.livingExpense or 0) .. " 两\n粮食：需 " .. tostring(ledger.foodNeed or 0) .. " 石 · 缺 " .. tostring(ledger.foodShortfall or 0) .. " 石 · 净变 " .. tostring(ledger.netGrain or 0) .. " 石", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.45 }),
        })
    end)
end

local function BuildFacts(app)
    local names = {
        job = "人生安排", marriage = "婚配", adoption = "收养", birth = "出生", exam = "应试", leadership = "族长交接",
        migration = "迁居", asset_purchase = "置办家业", grain_purchase = "公市购粮", community_aid = "乡里接济",
        relic = "信物故事", growth = "成长节点", annual_ledger = "年度结算", ending = "终章", habit = "家风经历", opening = "家谱开篇",
    }
    return PagedCards(app, "facts", app.run.facts or {}, 5, "事实记录", "尚无带参与人的事实记录。年度推进、人生安排和家业动作会从这里开始保留。", function(fact)
        local participants = {}
        for _, memberId in ipairs(fact.memberIds or {}) do
            local member = State.FindMember(app.run.members, memberId)
            if member then table.insert(participants, MemberButton(app, member.id, member.name)) end
        end
        if #participants == 0 then table.insert(participants, Text("全家记录", { fontSize = 13, fontColor = C.secondary })) end
        return Card({
            Text("大晟历 " .. tostring(fact.year) .. " 年 · " .. (names[fact.kind] or tostring(fact.kind)), { fontSize = 14, fontWeight = "bold", fontColor = C.primary }),
            Text(fact.text, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }),
            Text("参与人", { fontSize = 13, fontColor = C.secondary }),
            UI.SimpleGrid { columns = 2, gap = 5, children = participants },
        }, { padding = 10 })
    end)
end

local function BuildAnnals(app)
    return PagedCards(app, "annals", app.run.logs or {}, 10, "年鉴", "家史尚未写下新事。", function(log)
        return Card({ Text("大晟历 " .. tostring(log.year) .. " 年", { fontSize = 14, fontWeight = "bold", fontColor = C.primary }), Text(log.text, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }) }, { padding = 10 })
    end)
end

local function BuildEndings(app)
    local endings = {}
    for _, ending in ipairs(Data.Endings) do
        if ending.id ~= "collapse" and ending.automaticTrigger ~= "resources_exhausted" then table.insert(endings, ending) end
    end
    local currentEnding = app.run.ending
    local cards = {}
    for _, ending in ipairs(endings) do
        local progress = Simulation.EndingProgress(app.run, ending.id)
        local lines = {}
        for _, item in ipairs(progress) do table.insert(lines, ProgressText(item)) end
        local action
        if currentEnding and currentEnding.id == ending.id then
            action = Text(ending.automatic and "已自然写入本局终章" or "已作为本局主终章写入家史", { fontSize = 13, fontColor = C.primary, whiteSpace = "normal" })
        elseif ending.automatic then
            action = Text(ending.automaticHint or "全体在世族人归零后自然写入家史。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" })
        elseif app.run.ending then
            action = Text("本局已落笔，条件保留供回顾。", { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" })
        elseif Simulation.IsEndingReady(app.run, ending.id) then
            action = Button("以此落笔", function() app:ConfirmEnding(ending.id) end, { height = 48, role = "primary" })
        else
            action = Text("仍可探索", { fontSize = 13, fontColor = C.secondary })
        end
        table.insert(cards, Card({
            Text(ending.title, { fontSize = 17, fontWeight = "bold" }),
            Text(ending.desc, { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 }),
            Text(table.concat(lines, " · "), { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.4 }),
            action,
        }))
    end
    if currentEnding then
        local record = currentEnding
        local evidence = {}
        for _, item in ipairs(record.evidence or {}) do table.insert(evidence, Text(EndingEvidenceText(item), { fontSize = 13, fontColor = C.secondary, whiteSpace = "normal" })) end
        table.insert(cards, 1, Card({
            Text("本局终章 · " .. tostring(record.title), { fontSize = 19, fontWeight = "bold" }),
            Text(record.automatic and "自然终局已写入家史。" or "主终章已由家主确认，家史现为只读。", { fontSize = 13, fontColor = C.secondary }),
            Text(tostring(record.summary or "这段家史已被妥善收录。"), { fontSize = 14, whiteSpace = "normal", lineHeight = 1.45 }),
            UI.Panel { gap = 5, children = evidence },
        }))
    end
    return PagedCards(app, "endings", cards, 4, "终章", "发展终章仍在探索中。", function(card) return card end)
end

function HistoryView.Build(app)
    app.historySection = app.historySection or "ledgers"
    app.historyPages = app.historyPages or {}
    local selected = app.historySection
    local function select(section)
        app.historySection = section
        app:Render()
    end
    local function tab(id, label)
        local active = selected == id
        return Button(label, function() select(id) end, { flex = 1, height = 44, selected = active, role = active and "primary" or "secondary" })
    end

    local sectionContent
    if selected == "terms" then sectionContent = BuildTerms(app)
    elseif selected == "ledgers" then sectionContent = BuildLedgers(app)
    elseif selected == "facts" then sectionContent = BuildFacts(app)
    elseif selected == "endings" then sectionContent = BuildEndings(app)
    else sectionContent = BuildAnnals(app) end

    return UI.Panel { gap = 12, children = {
        Card({
            Text("家史", { fontSize = 21, fontWeight = "bold" }),
            Text("年鉴、任期、账本、事实和终章按类别保留，长记录可分页阅读。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal" }),
            UI.Row { gap = 6, children = {
                Button("导出本局", function() app:Export() end, { flex = 1, role = "primary" }),
                Button("导入备份", function() app:OpenImport() end, { flex = 1 }),
                Button("新立家谱", function() app:PrepareNewRun() end, { flex = 1 }),
            } },
        }),
        UI.Row { gap = 6, children = { tab("annals", "年鉴"), tab("terms", "历任"), tab("ledgers", "账本") } },
        UI.Row { gap = 6, children = { tab("facts", "事实"), tab("endings", "终章") } },
        sectionContent,
    } }
end

return HistoryView
