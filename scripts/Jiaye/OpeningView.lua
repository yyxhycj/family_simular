local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Opening = require "Jiaye.Opening"
local Economy = require "Jiaye.Economy"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"

local View = {}
local C = {
    paper = V7.Colors.paper, card = V7.Colors.paperLight, ink = V7.Colors.ink,
    muted = V7.Colors.secondary, line = V7.Colors.rule, green = V7.Colors.primary,
    pale = V7.Colors.selected, warning = V7.Colors.danger, gold = V7.Colors.gold,
}

local function draftOf(app)
    return app.openingEditDraft or app.draft
end

local function text(value, size, color, extra)
    local props = extra or {}
    props.fontSize = size or props.fontSize or 15
    props.fontColor = color or props.fontColor or C.ink
    props.whiteSpace = props.whiteSpace or "normal"
    props.flexShrink = props.flexShrink or 0
    return Visual.Text(tostring(value or ""), props)
end

local function button(label, action, secondary, extra)
    local props = extra or {}
    props.role = secondary and "secondary" or (props.role or "primary")
    props.height = props.height or 44
    props.fontSize = props.fontSize or 15
    props.flexShrink = props.flexShrink or 0
    return Visual.Button(label, action, props)
end

local function card(children, extra)
    local props = extra or {}
    props.gap = props.gap or 8
    props.padding = props.padding == nil and 12 or props.padding
    props.flexShrink = props.flexShrink or 0
    return Visual.Card(children, props)
end

local function row(children, extra)
    local props = extra or {}
    props.gap = props.gap or 8
    props.flexShrink = props.flexShrink or 0
    props.children = children
    return UI.Row(props)
end

local function field(value, onChange, id)
    return UI.TextField {
        id = id, value = value or "", onChange = onChange, height = 44,
        fontSize = 16, maxLength = 20, backgroundColor = C.card,
        textColor = C.ink, borderColor = C.line,
    }
end

local function choose(items, value, onChange)
    return UI.Dropdown {
        options = items, value = value, height = 44, fontSize = 15, maxVisibleItems = 6,
        onChange = function(_, selected) onChange(selected) end,
    }
end

local function options(items)
    local result = {}
    for _, item in ipairs(items) do
        table.insert(result, { value = item.id, label = item.name .. " · " .. tostring(item.cost or 0) .. " 点" })
    end
    return result
end

local function signed(value)
    return (value > 0 and "+" or "") .. tostring(value)
end

local function sectionTitle(title, detail, action)
    local content = row({
        row({ text("◇", 18, C.gold), text(title, 19) }, { alignItems = "center" }),
        detail and text(detail, 13, C.muted) or UI.Panel { width = 0 },
    }, { justifyContent = "space-between", alignItems = "center" })
    if not action then return content end
    return UI.Panel {
        height = 44, minHeight = 44, onClick = action, backgroundColor = false,
        pointerEvents = "box-only", children = { content },
    }
end

local function backgroundFor(draft)
    return State.BackgroundDefinition(draft)
end

local function assetCell(label, value, action)
    return UI.Panel {
        flex = 1, minWidth = 0, height = 58, padding = 5,
        justifyContent = "center", alignItems = "center",
        backgroundColor = C.card, borderRightWidth = 1, borderRightColor = C.line,
        onClick = action, children = { text(label, 11, C.muted), text(value, 16) },
    }
end

local function objectControls(app, page)
    if page == "name" then
        return row({
            button("骰子：随机姓氏", function() app:RandomFamilyName() end, true, { flex = 1 }),
        })
    end
    local used, available = State.PageBudget(draftOf(app), page)
    return row({
        button("对象随机", function() app:RandomizePage(page) end, true, { flex = 1 }),
        button("撤销", function() app:UndoPage(page) end, true, { flex = 1, disabled = app.undo[page] == nil }),
        text("100 − 其他对象 = " .. available .. " 点 · 已用 " .. used, 12, C.muted, { flex = 1, textAlign = "right" }),
    }, { alignItems = "center" })
end

local function preview(app)
    local run = State.NewRun(draftOf(app), app.profile)
    return run and Economy.Preview(run) or nil
end

local function show(app, view)
    app.openingView = view
    app.openingFeedback = ""
    app:Render()
end

local function backgroundInfo(d)
    local background = backgroundFor(d)
    if not background then return nil end
    local children = {
        text(background.name .. " · 背景定义", 17),
        text(background.history or "", 14, C.muted),
    }
    for _, contact in ipairs(background.contacts or {}) do
        table.insert(children, text("旧识 · " .. tostring(contact.name) .. " · " .. tostring(contact.relation), 14))
        table.insert(children, text(contact.history or "", 13, C.muted))
    end
    if background.effect then
        table.insert(children, text("当前作用 · " .. tostring(background.effect.description or "待确认"), 14))
        table.insert(children, text("适用条件 · " .. tostring(background.effect.condition or "待确认"), 13, C.muted))
    end
    local opportunity = background.opportunity
    if opportunity then
        table.insert(children, text("机会 · " .. tostring(opportunity.name or "待确认"), 14))
        table.insert(children, text("条件 · " .. tostring(opportunity.condition or "待确认"), 13, C.muted))
        if opportunity.status == "prototype" then
            table.insert(children, text("原型待确认 · " .. tostring(opportunity.pending or "费用与结果待确认"), 13, C.warning))
        else
            table.insert(children, text("费用与结果 · " .. tostring(opportunity.cost or "待确认") .. " · " .. tostring(opportunity.result or "待确认"), 13, C.muted))
        end
    end
    return card(children)
end

local function memberTile(app, member)
    local draft = draftOf(app)
    local job = Data.Jobs[member.jobId]
    local leader = member.id == draft.leaderId
    return UI.Panel {
        onClick = function() app:OpenDraftMember(member.id) end,
        height = 122, flex = 1, minWidth = 0, gap = 3, padding = 0,
        flexDirection = "column", alignItems = "center", backgroundColor = false,
        pointerEvents = "box-only",
        children = {
            Visual.Portrait(member, { size = 58, leader = leader }),
            text(member.name, 15, C.ink, { maxLines = 1, textAlign = "center" }),
            text(tostring(member.age) .. "岁 · 资质 " .. tostring(member.talent) .. "/5", 12, C.muted, { maxLines = 1, textAlign = "center" }),
            text(job and job.name or "待安排", 12, C.muted, { maxLines = 1, textAlign = "center" }),
        },
    }
end

local function relicSummary(app)
    local result = {}
    for _, id in ipairs(draftOf(app).selectedRelicIds or {}) do
        local relic = Data.Relic(id)
        if relic then table.insert(result, relic.name .. " · " .. relic.cost .. " 点") end
    end
    if #result == 0 then return "未带信物 · 可以空手开篇" end
    return table.concat(result, "；")
end

function View.Summary(app)
    local draft = app.draft
    local ledger = preview(app)
    local period = Data.Period(draft.periodId)
    local origin = Data.Origin(draft.originId)
    local place = Data.Place(draft.placeId)
    local background = backgroundFor(draft)
    local adults = 0
    for _, member in ipairs(draft.members) do if State.IsAdult(member) then adults = adults + 1 end end
    local children = {
        text("一家人的故事，从这里开始", 15, C.muted),
        row({
            UI.Panel { flex = 1, minWidth = 0, height = 44, justifyContent = "center", onClick = function() app:BeginOpeningEdit("name") end, children = { text(draft.family .. "氏家族", 25) } },
            button("改名", function() app:BeginOpeningEdit("name") end, true, { width = 58, height = 44 }),
            button("骰子", function() app:RandomFamilyName() end, true, { width = 58, height = 44 }),
        }),
        row({
            button("历 " .. tostring(draft.calendar) .. " 年", function() app:BeginOpeningEdit("world") end, true, { flex = 1, height = 44, fontSize = 13, paddingHorizontal = 4 }),
            button(background and background.name or origin.name, function() app:BeginOpeningEdit("world") end, true, { flex = 1, height = 44, fontSize = 13, paddingHorizontal = 4 }),
            button(place.short, function() app:BeginOpeningEdit("world") end, true, { flex = 1, height = 44, fontSize = 13, paddingHorizontal = 4 }),
        }, { gap = 5 }),
        UI.Panel { onClick = function() app:BeginOpeningEdit("estate") end, height = 110, padding = 0, backgroundColor = C.card, borderWidth = 1, borderColor = C.gold, children = {
            Visual.House(draft.homeId, "normal", { width = "100%", height = 108 }),
        } },
    }
    table.insert(children, UI.Panel { flexDirection = "row", height = 58, borderWidth = 1, borderColor = C.line, overflow = "hidden", onClick = function() app:BeginOpeningEdit("estate") end, children = {
        assetCell("现银", draft.money .. " 两"), assetCell("存粮", draft.grain .. " 石"),
        assetCell("田地", draft.land .. " 亩"), assetCell("住宅", Data.Home(draft.homeId).name),
    } })
    table.insert(children, text((draft.workshop and "有木工作坊" or "无木工作坊") .. " · " .. (draft.shop and "有小商铺" or "无小商铺"), 12, C.muted))
    table.insert(children, sectionTitle("家中 " .. #draft.members .. " 人", adults .. " 成人 · " .. (#draft.members - adults) .. " 孩子", function() app:BeginOpeningEdit("people") end))
    local tiles = {}
    for index = 1, math.min(4, #draft.members) do table.insert(tiles, memberTile(app, draft.members[index])) end
    table.insert(children, UI.SimpleGrid { columns = math.min(4, math.max(1, #tiles)), gap = 7, children = tiles })
    if #draft.members > #tiles then table.insert(children, button("查看全部 " .. #draft.members .. " 人  ›", function() app:OpenOpeningDetail("people") end, true)) end
    local firstRelic = draft.selectedRelicIds and draft.selectedRelicIds[1]
    table.insert(children, UI.Panel { onClick = function() app:BeginOpeningEdit("relics") end, height = 60, padding = 5, gap = 8, flexDirection = "row", alignItems = "center", backgroundColor = C.card, borderWidth = 1, borderColor = C.line, children = {
        firstRelic and Visual.Relic(firstRelic, 46) or text("物", 25, C.gold),
        UI.Panel { flex = 1, minWidth = 0, children = { text(firstRelic and Data.Relic(firstRelic).name or "本局未带入旧物", 15), text(relicSummary(app), 12, C.muted, { maxLines = 1 }) } },
        text("›", 22, C.muted),
    } })
    table.insert(children, row({ text("首年预计 · 不含突发", 14, C.muted), button(ledger and (signed(ledger.netMoney) .. " 两  " .. signed(ledger.netGrain) .. " 石  ›") or "请先修正草案", function() app:OpenOpeningDetail("ledger") end, true, { flex = 1, height = 44, fontSize = 14 }) }))
    return card(children)
end

local function ledgerView(app)
    local ledger = preview(app)
    if not ledger then return card({ text("草案存在错误，修正后即可查看首年预计收支。", 16, C.warning) }) end
    local children = { text("首年账本", 23), text("按当前安排和年初数值计算，不含突发事件。", 14, C.muted), text("现有 " .. ledger.beforeMoney .. " 两 / " .. ledger.beforeGrain .. " 石", 18) }
    for _, entry in ipairs(ledger.members or {}) do table.insert(children, text(entry.name .. " · " .. entry.job .. "：" .. signed(entry.money) .. " 两，" .. signed(entry.grain) .. " 石")) end
    table.insert(children, text("谋生收入 +" .. ledger.income .. " 两 · 产业 +" .. ledger.industryIncome .. " 两", 15))
    table.insert(children, text("培养支出 −" .. ledger.training .. " 两 · 生活开支 −" .. ledger.livingExpense .. " 两", 15))
    table.insert(children, text("预计年末 " .. ledger.money .. " 两 / " .. ledger.grain .. " 石", 17))
    return card(children)
end

local function pointsView(app)
    local draft = draftOf(app)
    local children = { text("开局点数明细", 23), text("共用 100 点，不设类别配额；姓名、性别、家风和成长偏向不单独出售。", 14, C.muted) }
    for _, entry in ipairs(State.PointLines(draft)) do
        if not string.find(entry.label or "", "偏向", 1, true) and not string.find(entry.label or "", "家风", 1, true) and not string.find(entry.label or "", "旧识", 1, true) then
            table.insert(children, card({ text(entry.label .. " · " .. entry.cost .. " 点", 16), text(entry.effect, 14, C.muted) }))
        end
    end
    return card(children)
end

local function peopleView(app)
    local draft = draftOf(app)
    local children = { text("全部 " .. #draft.members .. " 位族人", 23) }
    for _, member in ipairs(draft.members) do
        local stats = Data.Experience(member.experienceId).values
        table.insert(children, card({ row({ Visual.Portrait(member, { size = 52, leader = member.id == draft.leaderId }), UI.Panel { flex = 1, minWidth = 0, children = { text(member.name .. " · " .. member.age .. " 岁", 18), text("资质 " .. member.talent .. "/5 · " .. Data.Jobs[member.jobId].name, 14, C.muted) } }, button("编辑", function() app:OpenDraftMember(member.id) end, true, { width = 58 }) }), text("学识 " .. stats.learn .. " / 手艺 " .. stats.skill .. " / 医术 " .. stats.medicine .. " / 经营 " .. stats.trade .. " / 武艺 " .. stats.martial, 14, C.muted) }))
    end
    table.insert(children, button("添加族人", function() app:AddMember() end, true))
    return card(children)
end

local function relicView(app, editing)
    local draft = draftOf(app)
    local children = { text(editing and "信物选择" or "本局信物与收藏", 23), text("解锁是可选资格；只有选中的物件带入本局，共享 100 点。", 14, C.muted) }
    for _, relic in ipairs(Data.Relics) do
        local selected = false
        for _, id in ipairs(draft.selectedRelicIds or {}) do if id == relic.id then selected = true end end
        local unlocked = app.profile.unlockedRelicIds[relic.id]
        local action = editing and button(not unlocked and "尚未解锁" or (selected and "✓ 已带入" or "选入本局"), function() app:ToggleRelic(relic.id) end, not selected, { disabled = not unlocked }) or text(not unlocked and "尚未解锁" or (selected and "✓ 本局带入" or "已解锁 · 本局未带入"), 14, C.muted)
        table.insert(children, card({ row({ Visual.Relic(relic.id, 42), UI.Panel { flex = 1, minWidth = 0, children = { text(relic.name .. " · " .. relic.cost .. " 点", 18), text(relic.desc, 14, C.muted) } }, action }) }))
    end
    return card(children)
end

local function editor(app)
    local draft, page = draftOf(app), app.openingPage
    local children = { text("编辑对象", 23), text("修改只写入临时草案；保存并返回才提交，取消会完整丢弃。", 14, C.muted) }
    table.insert(children, objectControls(app, page))
    if page == "name" then
        table.insert(children, text("家族称谓", 17))
        table.insert(children, field(app.nameEditing or draft.family, function(_, value) app.nameEditing = value end, "opening-family-name"))
        table.insert(children, text("骰子只随机姓氏；外姓、自定义姓名和关系保持原样。", 14, C.muted))
    elseif page == "world" then
        table.insert(children, text("时间与背景", 17))
        table.insert(children, choose(options(Data.Periods), draft.periodId, function(id) app:SelectPeriod(id) end))
        local years = {}; for _, year in ipairs(Data.Period(draft.periodId).years) do table.insert(years, { value = year, label = "大晟历 " .. year .. " 年" }) end
        table.insert(children, choose(years, draft.calendar, function(value) app:SetDraftField("world", "calendar", value) end))
        table.insert(children, choose(options(Data.Origins), draft.originId, function(value) app:SetDraftField("world", "originId", value) end))
        table.insert(children, choose(options(Data.Places), draft.placeId, function(value) app:SetDraftField("world", "placeId", value) end))
        local details = backgroundInfo(draft); if details then table.insert(children, details) end
        table.insert(children, text("家风与旧识在真实经历中形成，开局不单独购买。", 14, C.muted))
    elseif page == "people" then
        table.insert(children, peopleView(app))
    elseif page == "estate" then
        for _, item in ipairs({ {label = "现银", key = "money", max = 300, step = Data.OpeningCosts.moneyUnit, suffix = " 两"}, {label = "存粮", key = "grain", max = 160, step = Data.OpeningCosts.grainUnit, suffix = " 石"}, {label = "田地", key = "land", max = 12, step = 1, suffix = " 亩"} }) do
            table.insert(children, UI.Panel { gap = 5, children = { text(item.label .. "：" .. draft[item.key] .. item.suffix, 17), row({ button("−", function() app:SetDraftField("estate", item.key, math.max(0, draft[item.key] - item.step)) end, true, { width = 44, disabled = draft[item.key] <= 0 }), UI.Panel { flex = 1, height = 44, justifyContent = "center", alignItems = "center", backgroundColor = C.card, borderWidth = 1, borderColor = C.line, children = { text(draft[item.key] .. item.suffix, 18) } }, button("+", function() app:SetDraftField("estate", item.key, math.min(item.max, draft[item.key] + item.step)) end, true, { width = 44, disabled = draft[item.key] >= item.max }) }) } })
        end
        table.insert(children, choose(options(Data.Homes), draft.homeId, function(value) app:SetDraftField("estate", "homeId", value) end))
        for _, item in ipairs({ {name = "木工作坊", key = "workshop", cost = Data.OpeningCosts.workshop}, {name = "小商铺", key = "shop", cost = Data.OpeningCosts.shop} }) do
            table.insert(children, button((draft[item.key] and "✓ " or "") .. item.name .. " · " .. item.cost .. " 点", function() app:SetDraftField("estate", item.key, not draft[item.key]) end, not draft[item.key]))
        end
    elseif page == "relics" then
        table.insert(children, relicView(app, true))
    elseif page == "ledger" then
        table.insert(children, ledgerView(app))
    elseif page == "points" then
        table.insert(children, pointsView(app))
    end
    return card(children)
end

local function memberView(app)
    local member, draft = app.memberEditing, draftOf(app)
    local children = { text(member.name .. " · 临时编辑", 23), text("保存后生效，取消不改草案。", 14, C.muted), row({
        button("概况", function() app.memberSection = "base"; app:Render() end, app.memberSection ~= "base", { flex = 1 }),
        button("本领与安排", function() app.memberSection = "skills"; app:Render() end, app.memberSection ~= "skills", { flex = 1 }),
        button("亲属", function() app.memberSection = "relations"; app:Render() end, app.memberSection ~= "relations", { flex = 1 }),
    }) }
    local function change(key, value)
        member[key] = value
        if key == "sex" then
            member.artId = nil
            V7.Art.Assign(member, draft.rngSeed)
        end
        app.memberIssue = ""; app:Render()
    end
    if app.memberSection == "base" then
        table.insert(children, field(member.name, function(_, value) member.name = value; member.nameSource = "custom" end, "opening-member-name-" .. tostring(member.id)))
        table.insert(children, row({ text("年龄 " .. member.age .. " 岁", 17), button("−", function() change("age", math.max(0, member.age - 1)) end, true, { width = 44 }), button("+", function() change("age", math.min(92, member.age + 1)) end, true, { width = 44 }) }))
        table.insert(children, choose({ {value = "男", label = "男"}, {value = "女", label = "女"} }, member.sex, function(value) change("sex", value) end))
        table.insert(children, button(app.memberLeader == member.id and "✓ 首任族长" or "设为首任族长", function() app.memberLeader = member.id; app:Render() end, true, { disabled = member.age < Data.AgeRules.adult }))
    elseif app.memberSection == "skills" then
        local talents = {}; for i, talent in ipairs(Data.Talents) do table.insert(talents, { value = i, label = talent.name .. " · " .. talent.cost .. " 点" }) end
        table.insert(children, choose(talents, member.talent, function(value) change("talent", value) end))
        table.insert(children, choose(options(Data.Experiences), member.experienceId, function(value) change("experienceId", value) end))
        local values = Data.Experience(member.experienceId).values
        table.insert(children, text("学识 " .. values.learn .. " / 手艺 " .. values.skill .. " / 医术 " .. values.medicine .. " / 经营 " .. values.trade .. " / 武艺 " .. values.martial, 14, C.muted))
        local jobs = {}; for _, id in ipairs(Data.JobOrder) do local ok, reason = State.CanUseJob({ age = member.age, stats = values }, id); table.insert(jobs, { value = id, label = Data.Jobs[id].name .. (ok and "" or " · " .. reason), disabled = not ok }) end
        table.insert(children, choose(jobs, member.jobId, function(value) change("jobId", value) end))
    else
        table.insert(children, text("父母/养亲 · 最多两位；关系在保存时统一校验。", 15, C.muted))
        for _, other in ipairs(draft.members) do if other.id ~= member.id then
            local selected = false; for _, id in ipairs(member.parents or {}) do if id == other.id then selected = true end end
            table.insert(children, button((selected and "✓ " or "") .. other.name .. " · " .. other.age .. " 岁", function()
                local parents = {}; for _, id in ipairs(member.parents or {}) do if id ~= other.id then table.insert(parents, id) end end
                if not selected then table.insert(parents, other.id) end; change("parents", parents)
            end, not selected, { disabled = not selected and (other.age - member.age < 18 or #(member.parents or {}) >= 2) }))
        end end
        local spouses = { { value = 0, label = "无配偶" } }; for _, other in ipairs(draft.members) do if other.id ~= member.id then table.insert(spouses, { value = other.id, label = other.name .. " · " .. other.age .. " 岁" }) end end
        table.insert(children, choose(spouses, member.spouseId or 0, function(value) change("spouseId", value ~= 0 and value or nil) end))
        if not app.memberIsNew then table.insert(children, button(app.memberRemoving and "已标记移除" or "移除此人…", function() app:MarkDraftMemberForRemoval() end, true)) end
    end
    local candidate, issue = app:DraftMemberCandidate()
    if candidate then
        local memberCost = State.MemberCost(member)
        local available = Data.LIMIT - (State.TotalPoints(candidate) - (app.memberRemoving and 0 or memberCost))
        table.insert(children, text((app.memberRemoving and "移除该成员 · 将节省 " .. memberCost .. " 点" or "本成员费用 " .. memberCost .. " 点") .. " · 100 − 其他费用 = " .. available .. " 点 · 保存后总分 " .. State.TotalPoints(candidate) .. "/100", 13, C.muted))
    else
        table.insert(children, text(issue or "成员候选无效。", 14, C.warning))
    end
    return card(children)
end

function View.Build(app)
    local view = app.openingView or "summary"
    local content
    if view == "summary" then content = View.Summary(app)
    elseif view == "editor" or view == "name" then content = editor(app)
    elseif view == "member" then content = memberView(app)
    elseif view == "ledger" then content = ledgerView(app)
    elseif view == "points" then content = pointsView(app)
    elseif view == "people" then content = peopleView(app)
    elseif view == "relics" then content = relicView(app, false)
    else content = View.Summary(app) end
    local footer
    if view == "summary" then
        local issues = State.ValidateDraft(app.draft, app.profile, false)
        footer = {
            UI.Panel {
                height = 44, minHeight = 44, onClick = function() app:OpenOpeningDetail("points") end,
                backgroundColor = false, pointerEvents = "box-only", flexDirection = "row",
                justifyContent = "space-between", alignItems = "center", children = {
                    text("总分 " .. State.TotalPoints(app.draft) .. "/100 · " .. (#issues > 0 and "请先修正草案" or "可以开局"), 13, #issues > 0 and C.warning or C.muted),
                    text("点数明细 ›", 13, C.muted),
                },
            },
            row({
                button("↻ 换一家", function() app:ChangeHouse() end, true, { flex = 1, height = 48 }),
                button("就从这家开始  →", function() app:StartRun() end, false, { flex = 2, height = 48, disabled = #issues > 0 }),
            }),
        }
        if #issues > 0 then table.insert(footer, 2, text(table.concat(issues, "\n"), 13, C.warning)) end
        local links = {}
        if app.houseUndo then table.insert(links, button("撤销换家", function() app:UndoHouse() end, true, { flex = 1, height = 44, fontSize = 12 })) end
        if app.previousDraft then table.insert(links, button("回原家谱", function() app:CancelNewRun() end, true, { flex = 1, height = 44, fontSize = 12 })) end
        if #links > 0 then table.insert(footer, row(links)) end
    elseif view == "member" then
        footer = { row({ button("取消", function() app:CancelDraftMember() end, true, { flex = 1 }), button(app.memberRemoving and "保存移除" or "保存人物", function() app:SaveDraftMember() end, false, { flex = 1 }) }) }
    elseif view == "editor" or view == "name" then
        footer = { row({ button("取消", function() app:FinishOpeningEdit(false) end, true, { flex = 1 }), button("保存并返回", function()
            if view == "name" then
                local candidate = State.Copy(app.openingEditDraft or app.draft)
                local ok, message = Opening.Rename(candidate, app.nameEditing or candidate.family)
                if not ok then app.openingFeedback = message; app:Render(); return end
                app.openingEditDraft = candidate
            end
            app:FinishOpeningEdit(true)
        end, false, { flex = 1 }) }) }
    else
        footer = { button("返回这户家庭", function() app:ReturnOpeningDetail() end, true) }
    end
    local body = { content }
    if app.openingFeedback ~= "" then table.insert(body, 1, text(app.openingFeedback, 14, C.warning)) end
    local contentPanel = UI.Panel {
        width = "100%", alignSelf = "stretch", flexShrink = 0, minHeight = 0,
        flexDirection = "column", gap = 10, padding = 0, children = body,
    }
    return UI.Panel {
        width = "100%", height = "100%", backgroundColor = C.paper,
        backgroundImage = V7.Images.paperTexture, backgroundImageOpacity = 1,
        backgroundFit = "cover", flexDirection = "column", padding = 0,
        children = {
            UI.Panel { height = 52, padding = 12, flexShrink = 0, borderBottomWidth = 1, borderBottomColor = C.line, children = {
                row({ Visual.Decor("seal_square", { width = 28, height = 28 }), text("家业", 20), text(view == "summary" and ("凡世王朝 · " .. Data.WORLD_NAME) or "开局草案", 12, C.muted) }, { alignItems = "center" }),
            } },
            UI.ScrollView { width = "100%", flexGrow = 1, flexBasis = 0, minHeight = 0, padding = 12, children = { contentPanel } },
            UI.Panel { padding = 12, gap = 6, backgroundColor = C.card, flexShrink = 0, borderTopWidth = 1, borderTopColor = C.line, children = footer },
        },
    }
end

return View
