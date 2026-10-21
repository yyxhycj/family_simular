local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Opening = require "Jiaye.Opening"
local Economy = require "Jiaye.Economy"
local RelicDefinitions = require "Jiaye.RelicDefinitions"
local RelicState = require "Jiaye.RelicState"
local Art = require "Jiaye.Art"
local Skin = require "Jiaye.QianjiajiSkin"

local View = {}
local C = Skin.Colors
local groupNames = {world = "时世与出身", people = "家中族人", estate = "家业置办", relics = "家传旧物"}

local function draftOf(app) return app.openingEditDraft or app.draft end
local function signed(value) return (value > 0 and "+" or "") .. tostring(value) end
local function note(value) return Skin.Text(value, {fontSize = 14, fontColor = C.muted}) end
local function row(children, props)
    local p = props or {}
    p.width, p.gap, p.flexShrink, p.children = p.width or "100%", p.gap or 12, 0, children
    return UI.Row(p)
end

local function choices(items)
    local result = {}
    for _, item in ipairs(items) do result[#result + 1] = {value = item.id, label = item.name .. " · " .. tostring(item.cost or 0) .. " 点"} end
    return result
end

local function choose(items, value, onChange, id)
    return UI.Dropdown {id = id, width = "100%", options = items, value = value, height = 48,
        fontFamily = Skin.FontFamily, fontSize = Skin.Font(17), maxVisibleItems = 6, borderRadius = 2,
        onChange = function(_, selected) onChange(selected) end}
end

local function field(value, onChange, id, size)
    return UI.TextField {id = id, width = "100%", value = value, maxLength = 20, height = 52,
        fontFamily = Skin.FontFamily, fontSize = Skin.Font(size or 20),
        backgroundColor = C.paperLight, textColor = C.ink, borderWidth = 1, borderColor = C.rule,
        focusedBorderColor = C.ink, onChange = function(_, text) onChange(text) end}
end

local function finishEdit(app)
    if app.openingPage == "name" then
        local candidate = State.Copy(draftOf(app))
        local ok, message = Opening.Rename(candidate, app.nameEditing or candidate.family)
        if not ok then app.openingFeedback = message; app:Render(); return end
        app.openingEditDraft = candidate
    end
    app:FinishOpeningEdit(true)
end

local function page(app, title, children, props)
    local p = props or {}
    p.id, p.title, p.children = "opening-" .. (p.pageId or app.openingView), title, children
    p.feedback = p.feedback or app.openingFeedback
    if p.editing then
        p.onCancel = p.onCancel or function() app:FinishOpeningEdit(false) end
        p.onSave = p.onSave or function() finishEdit(app) end
        p.footerNote = p.footerNote or ("开局点数 " .. State.TotalPoints(draftOf(app)) .. " / " .. Data.LIMIT)
    else
        p.onBack = p.onBack or function() app:ReturnOpeningDetail() end
    end
    return Skin.Page(p)
end

local function editLink(app, title, detail, object, id)
    return UI.Panel {id = id, minHeight = 48, width = "100%", pointerEvents = "box-only",
        onClick = function() app:BeginOpeningEdit(object) end,
        children = {row({Skin.Text(title, {fontSize = 17}), UI.Panel {flex = 1}, note(detail), Skin.Icon("chevron_right", 18)}, {alignItems = "center"})}}
end

local function randomControls(app, object)
    return row({
        Skin.TextAction("重新拟定", function() app:RandomizePage(object) end, {flex = 1}),
        Skin.TextAction("撤销重拟", function() app:UndoPage(object) end, {flex = 1, disabled = app.undo[object] == nil}),
    })
end

local function relationText(draft, member)
    local lines = {}
    local parents = {}
    for _, id in ipairs(member.parents or {}) do
        local parent = State.FindMember(draft.members, id)
        if parent then parents[#parents + 1] = parent.name end
    end
    if #parents > 0 then lines[#lines + 1] = "双亲 · " .. table.concat(parents, "、") end
    local spouse = member.spouseId and State.FindMember(draft.members, member.spouseId)
    if spouse then lines[#lines + 1] = "配偶 · " .. spouse.name end
    local children = {}
    for _, other in ipairs(draft.members) do
        for _, id in ipairs(other.parents or {}) do
            if id == member.id then children[#children + 1] = other.name; break end
        end
    end
    if #children > 0 then lines[#lines + 1] = "子女 · " .. table.concat(children, "、") end
    return #lines > 0 and table.concat(lines, "\n") or "亲属尚未记载"
end

local function selectedRelics(draft)
    return Opening.IsNewRelicDraft(draft) and draft.selectedRelicFormIds or draft.selectedRelicIds
end

local function relicInfo(draft, id)
    if Opening.IsNewRelicDraft(draft) then
        local form = assert(RelicDefinitions.Form(id), "信物形态未登记。")
        local aliases = {genealogy = "book", ruler = "ruler", letter = "letter", plan = "plan", jade = "jade", notes = "notes"}
        local base = assert(Data.Relic(aliases[form.familyId]), "信物来历未登记。")
        local userId = draft.relicUsers and draft.relicUsers[id]
        local user = userId and State.FindMember(draft.members, userId)
        return {id = id, name = form.name, cost = form.openingPoints, effect = form.description,
            origin = form.openingHistory or base.desc, form = form, userId = userId,
            holder = user and user.name or "暂未指定", sale = form.saleSilver or 0}
    end
    local relic = assert(Data.Relic(id), "信物未登记。")
    return {id = id, name = relic.name, cost = relic.cost, effect = relic.desc, origin = relic.story.body,
        holder = State.FindMember(draft.members, draft.leaderId).name, sale = relic.saleValue or 0}
end

local function ledger(app)
    local run = State.PreviewRun(draftOf(app), app.profile)
    return run and Economy.Preview(run) or nil
end

local function sectionHeading(title, action, label, id)
    return row({Skin.Text(title, {fontSize = 21}), UI.Panel {flex = 1}, Skin.TextAction(label or "查看 ›", action, {id = id, fontSize = 15})}, {alignItems = "center"})
end

function View.Summary(app)
    app.openingDetailHistory = {}
    local draft = app.draft
    local period, place = Data.Period(draft.periodId), Data.Place(draft.placeId)
    local background = State.BackgroundDefinition(draft)
    local relicIds = selectedRelics(draft) or {}
    local forecast = ledger(app)
    local adults = 0
    for _, member in ipairs(draft.members) do if State.IsAdult(member) then adults = adults + 1 end end
    local hero = UI.Panel {width = "100%", height = 330, flexShrink = 0, children = {
        Skin.Image(Skin.Art.world, {position = "absolute", left = -24, right = -24, top = -12, height = 160}),
        UI.Panel {position = "absolute", left = 0, right = 0, bottom = 0, gap = 6, children = {
            Skin.Text("大晟历 " .. draft.calendar .. " 年 · " .. place.short, {fontSize = 14}),
            row({Skin.Text(draft.family .. "氏家谱", {fontSize = 36, fontWeight = "bold"}), Skin.IconAction("edit", function() app:BeginOpeningEdit("name") end, {id = "opening-edit-name"})}, {alignItems = "center", gap = 8}),
            note(period.name .. " · " .. (background and background.name or Data.Origin(draft.originId).name)),
            row({Skin.TextAction("改写出身 ›", function() app:BeginOpeningEdit("origin") end, {id = "opening-edit-origin", fontSize = 15}),
                UI.Panel {flex = 1}, Skin.TextAction("另择一姓", function() app:RandomFamilyName() end, {id = "opening-random-name", fontSize = 15})}),
        }},
    }}
    local home = Data.Home(draft.homeId)
    local assets = {}
    for _, item in ipairs({{"现银", draft.money .. " 两"}, {"存粮", draft.grain .. " 石"}, {"田地", draft.land .. " 亩"}}) do
        assets[#assets + 1] = UI.Panel {flex = 1, minWidth = 0, gap = 5, alignItems = "center", children = {note(item[1]), Skin.Text(item[2], {fontSize = 22})}}
    end
    local family = {}
    for index = 1, math.min(4, #draft.members) do
        local member = draft.members[index]
        family[#family + 1] = UI.Panel {id = "opening-person-" .. member.id, flex = 1, minWidth = 0, gap = 5, alignItems = "center", pointerEvents = "box-only",
            onClick = function() app:OpenOpeningDetail("person", member.id) end, children = {
                Skin.Image(Art.Portrait(member), {width = "100%", height = 104}),
                Skin.Text(member.name, {fontSize = 17, textAlign = "center", width = "100%"}),
                Skin.Text(member.age .. "岁 · " .. Data.Jobs[member.jobId].name, {fontSize = 12, fontColor = C.muted, textAlign = "center", width = "100%"}),
                Skin.Text(member.id == draft.leaderId and "首任族长" or ("资质 " .. member.talent .. "/5"), {fontSize = 12, fontColor = member.id == draft.leaderId and C.red or C.muted}),
            }}
    end
    local relicNames = {}
    for _, id in ipairs(relicIds) do relicNames[#relicNames + 1] = relicInfo(draft, id).name end
    local children = {
        hero,
        UI.Panel {gap = 10, flexShrink = 0, children = {
            sectionHeading("家业", function() app:BeginOpeningEdit("estate") end, "置办 ›", "opening-edit-estate"),
            row({UI.Panel {flex = 1, minWidth = 0, gap = 6, justifyContent = "center", children = {Skin.Text(home.name, {fontSize = 22}),
                note((draft.workshop and "有作坊" or "无作坊") .. " · " .. (draft.shop and "有商铺" or "无商铺"))}},
                Skin.Image(Art.House(draft.homeId, "normal"), {width = "56%", height = 128})}, {alignItems = "center"}),
            row(assets), Skin.Line(),
        }},
        UI.Panel {gap = 10, flexShrink = 0, children = {
            row({Skin.Text("家中 " .. #draft.members .. " 人", {fontSize = 21}), UI.Panel {flex = 1}, note(adults .. " 成人 · " .. (#draft.members - adults) .. " 孩子")}, {alignItems = "center"}),
            row(family, {gap = 10}),
            Skin.TextAction("查看全家 " .. #draft.members .. " 人 ›", function() app:OpenOpeningDetail("people") end, {id = "opening-family-detail", alignSelf = "flex-end", fontSize = 15}),
        }},
        UI.Panel {id = "opening-relic-detail", minHeight = 88, pointerEvents = "box-only", onClick = function() app:OpenOpeningDetail("relics") end,
            borderTopWidth = 1, borderTopColor = C.rule, borderBottomWidth = 1, borderBottomColor = C.rule, borderRadius = 0, paddingVertical = 10, children = {
                row({#relicIds > 0 and Skin.Image(Art.Relic(relicIds[1]), {width = 76, height = 76}) or Skin.Icon("book", 42),
                    UI.Panel {flex = 1, minWidth = 0, gap = 5, children = {Skin.Text("家传旧物", {fontSize = 21}), note(#relicNames > 0 and table.concat(relicNames, " · ") or "空手开篇，家史待续")}},
                    Skin.Icon("chevron_right", 18)}, {alignItems = "center"}),
            }},
        UI.Panel {id = "opening-ledger-detail", minHeight = 52, pointerEvents = "box-only", onClick = function() app:OpenOpeningDetail("ledger") end, children = {
            row({UI.Panel {flex = 1, gap = 3, children = {Skin.Text("首年预计", {fontSize = 19}), note("不含突发")}},
                Skin.Text(forecast and (signed(forecast.netMoney) .. " 两  " .. signed(forecast.netGrain) .. " 石") or "请先修正草案", {fontSize = 20}),
                Skin.Icon("chevron_right", 18)}, {alignItems = "center"}),
        }},
        editLink(app, "时世与地域", period.name .. " · " .. place.short, "world", "opening-edit-world"),
    }
    local issues = State.ValidateDraft(draft, app.profile, false)
    local footer = {
        UI.Panel {id = "opening-points-detail", minHeight = 36, pointerEvents = "box-only", onClick = function() app:OpenOpeningDetail("points") end, children = {
            row({Skin.Text("开局点数 " .. State.TotalPoints(draft) .. " / " .. Data.LIMIT, {fontSize = 14, fontColor = #issues > 0 and C.red or C.muted}), UI.Panel {flex = 1}, note("明细 ›")}, {alignItems = "center"}),
        }},
        Skin.Button("就从这家开始  →", function() app:StartRun() end, {id = "opening-start", width = "100%", height = 52, fontSize = 19, disabled = #issues > 0}),
        row({Skin.TextAction("另择一家", function() app:ChangeHouse() end, {id = "opening-change-house", flex = 1}),
            app.houseUndo and Skin.TextAction("恢复上一家", function() app:UndoHouse() end, {id = "opening-undo-house", flex = 1}) or UI.Panel {width = 0},
            app.previousDraft and Skin.TextAction("回原家谱", function() app:CancelNewRun() end, {flex = 1}) or UI.Panel {width = 0}}, {gap = 8}),
    }
    if #issues > 0 then table.insert(footer, 2, Skin.Text(table.concat(issues, "\n"), {fontSize = 13, fontColor = C.red})) end
    return page(app, "开卷立家", children, {pageId = "summary", subtitle = "凡世王朝 · " .. Data.WORLD_NAME,
        onBack = function() app:ReturnToCover() end, backText = "首页", backId = "opening-home", gap = 18, footer = footer})
end

local function worldEditor(app)
    local draft = draftOf(app)
    local periods = {}
    for _, period in ipairs(Data.Periods) do
        periods[#periods + 1] = Skin.OptionRow {id = "opening-period-" .. period.id, label = period.name,
            description = period.desc or ("粮价 " .. period.food .. " 两/石 · 工资倍率 " .. string.format("%.2f", period.wage)),
            selected = draft.periodId == period.id, costText = period.cost .. " 点", onClick = function() app:SelectPeriod(period.id) end}
    end
    local years = {}
    for _, year in ipairs(Data.Period(draft.periodId).years) do years[#years + 1] = {value = year, label = "大晟历 " .. year .. " 年"} end
    local places = {}
    for _, place in ipairs(Data.Places) do
        places[#places + 1] = Skin.OptionRow {id = "opening-place-" .. place.id, label = place.name, description = place.desc .. "\n" .. (place.burden or ""),
            selected = draft.placeId == place.id, costText = place.cost .. " 点", onClick = function() app:SetDraftField("world", "placeId", place.id) end}
    end
    return page(app, "时世与地域", {
        Skin.Image(Skin.Art.world, {width = "100%", height = 160}),
        Skin.Section("时世", periods),
        Skin.Section("开篇年份", {choose(years, draft.calendar, function(value) app:SetDraftField("world", "calendar", value) end, "opening-calendar")}),
        Skin.Section("落脚之地", places),
        editLink(app, "家族出身", State.BackgroundDefinition(draft).name, "origin", "opening-origin-link"),
        randomControls(app, "world"),
    }, {pageId = "world", editing = true})
end

local function originEditor(app)
    local draft, options = draftOf(app), {}
    for _, background in ipairs(Data.Backgrounds) do
        local origin = Data.Origin(background.originId)
        options[#options + 1] = Skin.OptionRow {id = "opening-origin-" .. origin.id, label = background.name, description = background.history,
            costText = origin.cost .. " 点", selected = draft.originId == origin.id, onClick = function() app:SetDraftField("world", "originId", origin.id) end}
    end
    local background = State.BackgroundDefinition(draft)
    local story = {Skin.Text(background.history), note(background.effect.description), note(background.effect.condition)}
    for _, contact in ipairs(background.contacts or {}) do story[#story + 1] = note("旧识 · " .. contact.name .. " · " .. contact.relation .. "\n" .. contact.history) end
    if background.opportunity then
        local opportunity = background.opportunity
        story[#story + 1] = Skin.Text(opportunity.name, {fontSize = 19})
        story[#story + 1] = note(opportunity.condition)
        story[#story + 1] = note(opportunity.cost)
        story[#story + 1] = note(opportunity.result)
    end
    return page(app, "家族出身", {Skin.Image(Skin.Art.world, {width = "100%", height = 148}),
        Skin.Section("来历", options), Skin.Section(background.name, story)}, {pageId = "origin", editing = true})
end

local function surnameEditor(app)
    local draft = draftOf(app)
    local name = Skin.Text(app.nameEditing or draft.family, {fontSize = 38, width = 84, textAlign = "center"})
    return page(app, "家谱题签", {
        note("一姓为始，开卷立家"), Skin.Image(Skin.Art.world, {width = "100%", height = 148}),
        Skin.NineSlice("title_slip.png", 16, {width = 112, height = 184, alignSelf = "center", alignItems = "center", justifyContent = "center", gap = 12,
            children = {name, Skin.Text("氏家谱", {fontSize = 18})}}),
        field(app.nameEditing or draft.family, function(value) app.nameEditing = value; name:SetText(value) end, "opening-family-name", 24),
        Skin.TextAction("另择一姓", function() app:RandomFamilyName() end, {id = "opening-random-surname"}),
        note("改姓会联动随姓族人；自定义姓名与外姓保留。"),
    }, {pageId = "surname", editing = true})
end

local function estateEditor(app)
    local draft = draftOf(app)
    local children = {Skin.Image(Art.House(draft.homeId, "normal"), {width = "100%", height = 200}), Skin.Text(Data.Home(draft.homeId).name, {fontSize = 28})}
    for _, item in ipairs({
        {label = "现银", key = "money", max = 300, step = Data.OpeningCosts.moneyUnit, unit = "两", cost = 1},
        {label = "存粮", key = "grain", max = 160, step = Data.OpeningCosts.grainUnit, unit = "石", cost = 1},
        {label = "田地", key = "land", max = 12, step = 1, unit = "亩", cost = Data.OpeningCosts.land},
    }) do
        children[#children + 1] = UI.Panel {gap = 8, paddingVertical = 10, borderRadius = 0, borderBottomWidth = 1, borderBottomColor = C.rule, children = {
            row({UI.Panel {flex = 1, gap = 5, children = {Skin.Text(item.label, {fontSize = 20}), note("每 " .. item.step .. " " .. item.unit .. " · " .. item.cost .. " 点")}},
                Skin.Stepper {id = "opening-estate-" .. item.key, valueText = draft[item.key] .. item.unit, canDecrease = draft[item.key] > 0, canIncrease = draft[item.key] < item.max,
                    onDecrease = function() app:SetDraftField("estate", item.key, math.max(0, draft[item.key] - item.step)) end,
                    onIncrease = function() app:SetDraftField("estate", item.key, math.min(item.max, draft[item.key] + item.step)) end}}, {alignItems = "center"}),
        }}
    end
    local homes = {}
    for _, home in ipairs(Data.Homes) do homes[#homes + 1] = Skin.OptionRow {label = home.name, costText = home.cost .. " 点", description = "每年维护 " .. home.upkeep .. " 两", selected = draft.homeId == home.id,
        onClick = function() app:SetDraftField("estate", "homeId", home.id) end, id = "opening-home-" .. home.id} end
    children[#children + 1] = Skin.Section("住宅", homes)
    for _, item in ipairs({{key = "workshop", name = "木工作坊", cost = Data.OpeningCosts.workshop}, {key = "shop", name = "小商铺", cost = Data.OpeningCosts.shop}}) do
        children[#children + 1] = Skin.OptionRow {id = "opening-estate-" .. item.key, label = item.name, selected = draft[item.key], costText = item.cost .. " 点", onClick = function() app:SetDraftField("estate", item.key, not draft[item.key]) end}
    end
    children[#children + 1] = randomControls(app, "estate")
    return page(app, "家业置办", children, {pageId = "estate", editing = true})
end

local function peopleView(app, editing)
    local draft = draftOf(app)
    local members = State.Copy(draft.members)
    State.NormalizeGenerations(members)
    local groups, order = {}, {}
    for _, member in ipairs(members) do
        local generation = member.generation
        if not groups[generation] then groups[generation] = {}; order[#order + 1] = generation end
        groups[generation][#groups[generation] + 1] = Skin.MemberRow {id = "opening-family-member-" .. member.id,
            name = member.name, portrait = Art.Portrait(member), isLeader = member.id == draft.leaderId,
            relationText = relationText(draft, member), detailText = member.age .. " 岁 · 资质 " .. member.talent .. "/5 · " .. Data.Jobs[member.jobId].name,
            onClick = function() app:OpenOpeningDetail("person", member.id) end}
    end
    table.sort(order)
    ---@type Widget[]
    local children = {note("全家 " .. #draft.members .. " 人 · 点击族人查看小传与安排")}
    for _, generation in ipairs(order) do children[#children + 1] = Skin.Section("第 " .. generation .. " 世", groups[generation]) end
    children[#children + 1] = Skin.TextAction("添一位族人", function() app:AddMember() end, {id = "opening-add-member"})
    if editing then children[#children + 1] = randomControls(app, "people") end
    return page(app, "全家族人", children, {pageId = "family", editing = editing,
        onEdit = not editing and function() app:BeginOpeningEdit("people") end or nil, editId = "opening-edit-family"})
end

local function personView(app)
    local draft = draftOf(app)
    local member = assert(State.FindMember(draft.members, app.openingPersonId), "查看的族人不在当前草案中。")
    local experience = Data.Experience(member.experienceId)
    local stats = experience.values
    return page(app, "人物小传", {
        Skin.Image(Art.Portrait(member), {width = "100%", height = 258}),
        row({Skin.Text(member.name, {fontSize = 32}), UI.Panel {flex = 1}, Skin.Text(member.id == draft.leaderId and "首任族长" or "", {fontSize = 15, fontColor = C.red})}, {alignItems = "center"}),
        note(member.sex .. " · " .. member.age .. " 岁 · 资质 " .. member.talent .. "/5"),
        Skin.Text(member.trait or experience.name),
        Skin.Section("本领", {Skin.Text(experience.name), note("学识 " .. stats.learn .. " · 手艺 " .. stats.skill .. " · 医术 " .. stats.medicine .. "\n经营 " .. stats.trade .. " · 武艺 " .. stats.martial)}),
        Skin.Section("安排", {Skin.Text(Data.Jobs[member.jobId].name), note(Data.Jobs[member.jobId].desc)}),
        Skin.Section("亲属", {Skin.Text(relationText(draft, member))}),
    }, {pageId = "person", onEdit = function() app:OpenDraftMember(member.id) end, editId = "opening-edit-person"})
end

local function memberEditor(app)
    local member, draft = assert(app.memberEditing), draftOf(app)
    local section = app.memberSection or "base"
    local function change(key, value)
        member[key] = value
        if key == "sex" then member.artId = nil; Art.Assign(member, draft.rngSeed) end
        app.memberIssue = ""; app:Render()
    end
    ---@type Widget[]
    local children = {Skin.Image(Art.Portrait(member), {width = "100%", height = 208}),
        row({Skin.Text(member.name, {fontSize = 28}), UI.Panel {flex = 1}, note(member.age .. " 岁")}, {alignItems = "center"}),
        Skin.Tabs({{id = "base", label = "身份"}, {id = "skills", label = "本领"}, {id = "arrangement", label = "安排"}, {id = "relations", label = "亲属"}}, section, function(id) app.memberSection = id; app:Render() end)}
    if section == "base" then
        children[#children + 1] = Skin.Section("姓名", {field(member.name, function(value) member.name = value; member.nameSource = "custom" end, "opening-member-name-" .. member.id)})
        children[#children + 1] = Skin.Section("年龄", {Skin.Stepper {id = "opening-member-age", valueText = member.age .. " 岁", canDecrease = member.age > 0, canIncrease = member.age < 92,
            onDecrease = function() change("age", member.age - 1) end, onIncrease = function() change("age", member.age + 1) end}})
        children[#children + 1] = choose({{value = "男", label = "男"}, {value = "女", label = "女"}}, member.sex, function(value) change("sex", value) end, "opening-member-sex")
        children[#children + 1] = Skin.OptionRow {id = "opening-member-leader", label = "首任族长", selected = app.memberLeader == member.id, disabled = member.age < Data.AgeRules.adult,
            description = "成年族人可以担任族长。", onClick = function() app.memberLeader = member.id; app:Render() end}
    elseif section == "skills" then
        local talents = {}
        for index, talent in ipairs(Data.Talents) do talents[#talents + 1] = {value = index, label = talent.name .. " · " .. talent.cost .. " 点"} end
        children[#children + 1] = Skin.Section("资质", {choose(talents, member.talent, function(value) change("talent", value) end, "opening-member-talent")})
        children[#children + 1] = Skin.Section("已有本领", {choose(choices(Data.Experiences), member.experienceId, function(value) change("experienceId", value) end, "opening-member-experience")})
        local stats = Data.Experience(member.experienceId).values
        children[#children + 1] = note("学识 " .. stats.learn .. " · 手艺 " .. stats.skill .. " · 医术 " .. stats.medicine .. "\n经营 " .. stats.trade .. " · 武艺 " .. stats.martial)
    elseif section == "arrangement" then
        local stats = Data.Experience(member.experienceId).values
        for _, id in ipairs(Data.JobOrder) do
            local ok, reason = State.CanUseJob({age = member.age, stats = stats}, id)
            local job = Data.Jobs[id]
            children[#children + 1] = Skin.OptionRow {id = "opening-job-" .. id, label = job.name, description = ok and job.desc or reason,
                selected = member.jobId == id, disabled = not ok, onClick = function() change("jobId", id) end}
        end
    else
        children[#children + 1] = note("父母与养亲合计最多两位。")
        for _, other in ipairs(draft.members) do if other.id ~= member.id then
            local selected = false
            for _, id in ipairs(member.parents or {}) do if id == other.id then selected = true end end
            children[#children + 1] = Skin.OptionRow {id = "opening-parent-" .. other.id, label = other.name, description = other.age .. " 岁",
                selected = selected, disabled = not selected and (other.age - member.age < 18 or #(member.parents or {}) >= 2), onClick = function()
                    local parents = {}
                    for _, id in ipairs(member.parents or {}) do if id ~= other.id then parents[#parents + 1] = id end end
                    if not selected then parents[#parents + 1] = other.id end
                    change("parents", parents)
                end}
        end end
        local spouses = {{value = 0, label = "无配偶"}}
        for _, other in ipairs(draft.members) do if other.id ~= member.id then spouses[#spouses + 1] = {value = other.id, label = other.name .. " · " .. other.age .. " 岁"} end end
        children[#children + 1] = Skin.Section("配偶", {choose(spouses, member.spouseId or 0, function(id) change("spouseId", id ~= 0 and id or nil) end, "opening-member-spouse")})
        if not app.memberIsNew then children[#children + 1] = Skin.TextAction(app.memberRemoving and "已标记移除" or "移除此人", function() app:MarkDraftMemberForRemoval() end, {id = "opening-remove-member", textColor = C.red}) end
    end
    local candidate, issue = app:DraftMemberCandidate()
    local footerNote = candidate and ("本人成本 " .. State.MemberCost(member) .. " 点 · 保存后合计 " .. State.TotalPoints(candidate) .. " / " .. Data.LIMIT) or issue
    return page(app, "编辑人物", children, {pageId = "person-edit", editing = true, feedback = app.memberIssue, footerNote = footerNote, saveDisabled = candidate == nil,
        onCancel = function() app:CancelDraftMember() end, onSave = function()
            if app.memberRemoving then app.memberReturn = "people" end
            app:SaveDraftMember()
        end})
end

local function heirlooms(app, editing)
    local draft = draftOf(app)
    local ids = {}
    if editing then
        if Opening.IsNewRelicDraft(draft) then for _, form in ipairs(Opening.UnlockedRelicForms(app.profile)) do ids[#ids + 1] = form.id end
        else for _, relic in ipairs(Data.Relics) do if app.profile.unlockedRelicIds[relic.id] then ids[#ids + 1] = relic.id end end end
    else for _, id in ipairs(selectedRelics(draft) or {}) do ids[#ids + 1] = id end end
    ---@type Widget[]
    local children = {note(editing and "每条成长线可带入一件旧物，与家业和族人共用开局点数。" or "随这一家带入的旧物，来历与托付都将写进家谱。")}
    for _, id in ipairs(ids) do
        local info = relicInfo(draft, id)
        local selected = false
        for _, selectedId in ipairs(selectedRelics(draft) or {}) do if selectedId == id then selected = true end end
        ---@type Widget[]
        local content = {UI.Panel {id = "opening-relic-" .. id, pointerEvents = "box-only", onClick = function()
            if editing then app:ToggleRelic(id) else app:OpenOpeningDetail("heirloom", id) end
        end, children = {row({Skin.Image(Art.Relic(id), {width = 88, height = 100}), UI.Panel {flex = 1, minWidth = 0, gap = 6, children = {
            Skin.Text(info.name, {fontSize = 21}), note(info.effect), note(info.cost .. " 点 · " .. (selected and ("托付 · " .. info.holder) or "可带入"))}},
            Skin.Icon(editing and (selected and "checkbox_on" or "checkbox_off") or "chevron_right", 22)}, {alignItems = "center"})}}}
        if editing and selected and info.form then
            local holders = {{value = 0, label = "暂不指定使用者"}}
            for _, member in ipairs(draft.members) do
                local ok, reason = RelicState.EligibleUser({}, id, member)
                holders[#holders + 1] = {value = member.id, label = member.name .. " · " .. member.age .. " 岁" .. (ok and "" or (" · " .. reason)), disabled = not ok}
            end
            content[#content + 1] = choose(holders, info.userId or 0, function(value) app:SetRelicUser(id, value ~= 0 and value or nil) end, "opening-relic-holder-" .. id)
        end
        if editing then content[#content + 1] = Skin.TextAction("查看来历与作用 ›", function() app:OpenOpeningDetail("heirloom", id) end, {fontSize = 14, alignSelf = "flex-end"}) end
        children[#children + 1] = UI.Panel {width = "100%", gap = 10, paddingVertical = 12, borderRadius = 0, borderBottomWidth = 1, borderBottomColor = C.rule, children = content}
    end
    if #ids == 0 then children[#children + 1] = Skin.Text("本局未带入旧物。") end
    if editing then children[#children + 1] = randomControls(app, "relics") end
    return page(app, editing and "选择旧物" or "家传旧物", children, {pageId = editing and "heirlooms-edit" or "heirlooms", editing = editing,
        onEdit = not editing and function() app:BeginOpeningEdit("relics") end or nil, editId = "opening-edit-relics"})
end

local function heirloom(app)
    local draft = draftOf(app)
    local info = relicInfo(draft, app.openingRelicId)
    return page(app, "家传旧物", {Skin.Image(Art.Relic(info.id), {width = "100%", height = 240}),
        Skin.Text(info.name, {fontSize = 32}), note("带入 " .. info.cost .. " 点 · 出售 " .. info.sale .. " 两"),
        Skin.Section("来历", {Skin.Text(info.origin)}), Skin.Section("作用", {Skin.Text(info.effect)}),
        Skin.Section("托付", {Skin.Text(info.holder)})}, {pageId = "heirloom", onEdit = not app.openingEditDraft and function() app:BeginOpeningEdit("relics") end or nil, editId = "opening-edit-heirloom"})
end

local function amounts(silver, grain)
    return {{text = silver, unit = silver == "—" and "" or "两"}, {text = grain, unit = grain == "—" and "" or "石"}}
end

local function ledgerView(app)
    local forecast = ledger(app)
    if not forecast then return page(app, "首年账本", {Skin.Text("请先修正开局安排。")}, {pageId = "ledger"}) end
    local members = {}
    for _, entry in ipairs(forecast.members or {}) do members[#members + 1] = Skin.LedgerRow {label = entry.name, note = entry.job .. (entry.executed == false and (" · " .. entry.reason) or ""), values = amounts(signed(entry.money), signed(entry.grain))} end
    local memberGrain = 0
    for _, entry in ipairs(forecast.members or {}) do memberGrain = memberGrain + entry.grain end
    local marriage = forecast.marriage or {}
    local consumed = forecast.foodSatisfied and forecast.foodNeed or (forecast.foodNeed - forecast.foodShortfall)
    return page(app, "首年账本", {
        note("按当前安排计算，不含突发事件。"),
        Skin.LedgerRow {label = "年初家底", values = amounts(forecast.beforeMoney, forecast.beforeGrain)},
        Skin.Section("族人安排", members),
        Skin.Section("收入", {
            Skin.LedgerRow {label = "族人谋生", values = amounts(signed(forecast.income), signed(memberGrain))},
            Skin.LedgerRow {label = "田产与产业", values = amounts(signed(forecast.industryIncome), signed(forecast.landGrain))},
            Skin.LedgerRow {label = "信物年度收益", values = amounts(signed(forecast.relicIncome or 0), "—")},
            Skin.LedgerRow {label = "背景年度加成", values = amounts(signed(forecast.originIncome or 0), signed(forecast.originGrain or 0))},
            Skin.LedgerRow {label = "亲家往来", values = amounts(signed(marriage.money or 0), signed(marriage.grain or 0))},
            Skin.LedgerRow {label = "售出粮食", values = amounts(signed(forecast.saleIncome), signed(-forecast.grainSold))},
        }),
        Skin.Section("支出", {
            Skin.LedgerRow {label = "族人培养", values = amounts(signed(-forecast.training), "—")},
            Skin.LedgerRow {label = "生活用度", values = amounts(signed(-forecast.livingExpense), signed(-consumed))},
            Skin.LedgerRow {label = "补购口粮", values = amounts(signed(-forecast.foodCost), signed(forecast.boughtGrain))},
        }),
        Skin.LedgerRow {label = "首年净变动", total = true, values = amounts(signed(forecast.netMoney), signed(forecast.netGrain))},
        Skin.LedgerRow {label = "预计年末", total = true, values = amounts(forecast.money, forecast.grain)},
    }, {pageId = "ledger"})
end

local function pointsView(app)
    local draft = draftOf(app)
    local groups = {world = {}, people = {}, estate = {}, relics = {}}
    for _, entry in ipairs(State.PointLines(draft)) do
        groups[entry.group][#groups[entry.group] + 1] = Skin.LedgerRow {label = entry.label, note = entry.effect,
            values = {{text = entry.cost, unit = "点"}}, onClick = function() app:BeginOpeningEdit(entry.group) end}
    end
    local used = State.TotalPoints(draft)
    ---@type Widget[]
    local children = {note("共用 " .. Data.LIMIT .. " 点；超出时可继续编辑，调整到预算内即可开局。")}
    for _, group in ipairs({"world", "people", "estate", "relics"}) do children[#children + 1] = Skin.Section(groupNames[group], groups[group]) end
    children[#children + 1] = Skin.LedgerRow {label = "合计", total = true, values = {{text = used, unit = "点", color = used > Data.LIMIT and C.red or C.ink}}}
    return page(app, "开局点数", children, {pageId = "points"})
end

function View.Build(app)
    local view = app.openingView or "summary"
    if view == "summary" then return View.Summary(app) end
    if view == "name" then return surnameEditor(app) end
    if view == "member" then return memberEditor(app) end
    if view == "person" then return personView(app) end
    if view == "heirloom" then return heirloom(app) end
    if view == "people" then return peopleView(app, false) end
    if view == "relics" then return heirlooms(app, false) end
    if view == "ledger" then return ledgerView(app) end
    if view == "points" then return pointsView(app) end
    assert(view == "editor", "开局页面未登记：" .. tostring(view))
    local object = app.openingPage
    if object == "world" then return worldEditor(app) end
    if object == "origin" then return originEditor(app) end
    if object == "name" then return surnameEditor(app) end
    if object == "estate" then return estateEditor(app) end
    if object == "people" then return peopleView(app, true) end
    if object == "relics" then return heirlooms(app, true) end
    error("开局编辑页面未登记：" .. tostring(object))
end

return View
