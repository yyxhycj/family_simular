local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"

local App = {}
App.__index = App

local C = {
    paper = { 245, 243, 237, 255 }, card = { 255, 254, 250, 255 }, ink = { 38, 60, 51, 255 },
    muted = { 97, 107, 99, 255 }, line = { 221, 222, 218, 255 }, green = { 55, 99, 77, 255 },
    dark = { 45, 78, 59, 255 }, pale = { 232, 239, 221, 255 }, warning = { 164, 78, 56, 255 },
}

local function Label(text, props)
    props = props or {}; props.text = text; props.fontColor = props.fontColor or C.ink
    return UI.Label(props)
end

local function Button(text, onClick, props)
    props = props or {}; props.text = text; props.onClick = onClick; props.height = props.height or 46
    props.backgroundColor = props.backgroundColor or C.green; props.textColor = props.textColor or { 255, 255, 255, 255 }
    props.borderRadius = props.borderRadius or 10
    return UI.Button(props)
end

local function Card(children, props)
    props = props or {}; props.backgroundColor = props.backgroundColor or C.card; props.borderColor = props.borderColor or C.line
    props.borderWidth = props.borderWidth or 1; props.borderRadius = props.borderRadius or 14; props.padding = props.padding or 14; props.gap = props.gap or 9
    props.flexDirection = "column"; props.children = children
    return UI.Panel(props)
end

---@param value unknown
---@return table<any, any>
local function TableValue(value)
    return type(value) == "table" and value or {}
end

function App.New()
    local self = setmetatable({}, App)
    self:Init()
    return self
end

function App:Init()
    self.profile = State.NewProfile()
    self.draft = State.NewDraft()
    self.run = nil
    self.openingPage = "world"
    self.gameTab = "family"
    self.undo = {}
    self.root = nil
    self.previewLabel = nil
end

function App:Notify(message, variant)
    UI.Toast.Show(message, { variant = variant or "info", duration = 2.8, position = "top" })
end

function App:Save()
    local ok, message = State.Save(self.profile, self.draft, self.run)
    self:Notify(message, ok and "success" or "error")
end

function App:Load()
    local value, message = State.Load()
    if not value then self:Notify(message, "warning"); return end
    if type(value.profile) == "table" and type(value.draft) == "table" then
        self.profile, self.draft, self.run = value.profile, value.draft, value.run
        self:Render(); self:Notify(message, "success")
    else self:Notify("存档缺少必要字段，未覆盖当前进度。", "error") end
end

function App:Export()
    State.Export(self.profile, self.draft, self.run)
    self:Notify("备份已写入 jiaye_export.json，可从当前项目的本地存档空间取回。", "success")
end

function App:Random(max)
    self.draft.rngSeed = (self.draft.rngSeed * 48271) % 2147483647
    return math.floor(self.draft.rngSeed / 2147483647 * max) + 1
end

function App:RandomName(sex)
    local surnames = Data.Surnames
    local givenNames = Data.GivenNames[sex == "男" and "male" or "female"]
    return surnames[self:Random(#surnames)] .. givenNames[self:Random(#givenNames)]
end

function App:RandomFamilyName()
    local oldFamily = self.draft.family
    local nextFamily = Data.Surnames[self:Random(#Data.Surnames)]
    self.draft.family = nextFamily
    for _, member in ipairs(self.draft.members) do
        if member.name:sub(1, #oldFamily) == oldFamily then
            member.name = nextFamily .. member.name:sub(#oldFamily + 1)
        end
    end
    self:Render()
end

function App:UpdatePreview()
    if self.previewLabel then
        local total = State.TotalPoints(self.draft)
        self.previewLabel:SetText(self.draft.family .. "氏家谱 · " .. tostring(#self.draft.members) .. " 人 · " .. tostring(total) .. "/100 点")
    end
end

function App:SetOpeningPage(page)
    self.openingPage = page
    self:Render()
end

function App:SelectPeriod(id)
    local period = Data.Period(id)
    self.draft.periodId = id; self.draft.calendar = period.years[1]
    self:Render()
end

function App:ToggleRelic(id)
    local found = nil
    for index, item in ipairs(self.draft.selectedRelicIds) do if item == id then found = index end end
    if found then table.remove(self.draft.selectedRelicIds, found) else table.insert(self.draft.selectedRelicIds, id) end
    self:Render()
end

function App:RandomizePage(page)
    local before = State.Copy(self.draft)
    local generated = false
    for _ = 1, 20 do
        local candidate = State.Copy(before)
        if page == "world" then
            local period = Data.Periods[self:Random(#Data.Periods)]
            candidate.periodId = period.id; candidate.calendar = period.years[self:Random(#period.years)]
            candidate.originId = Data.Origins[self:Random(#Data.Origins)].id; candidate.placeId = Data.Places[self:Random(#Data.Places)].id
        elseif page == "people" then
            for _, member in ipairs(candidate.members) do
                member.talent = self:Random(#Data.Talents)
                member.experienceId = Data.Experiences[self:Random(#Data.Experiences)].id
            end
        elseif page == "estate" then
            candidate.money = (self:Random(10) - 1) * 10; candidate.grain = (self:Random(10) - 1) * 4; candidate.land = self:Random(4) - 1
            candidate.homeId = Data.Homes[self:Random(#Data.Homes)].id; candidate.workshop = self:Random(2) == 1; candidate.shop = self:Random(2) == 1
            candidate.habitId = Data.Habits[self:Random(#Data.Habits)].id; candidate.tieId = Data.Ties[self:Random(#Data.Ties)].id
        elseif page == "relics" then
            candidate.selectedRelicIds = {}
            for relicId in pairs(self.profile.unlockedRelicIds) do if self:Random(2) == 1 then table.insert(candidate.selectedRelicIds, relicId) end end
        end
        if #State.ValidateDraft(candidate, self.profile, false) == 0 then self.draft = candidate; generated = true; break end
    end
    if generated then self.undo[page] = before; self:Render(); self:Notify("已随机本页，其他页面保持不变。", "success") else self:Notify("当前其他页面已占用过多预算，无法生成合法本页方案。", "warning") end
end

function App:UndoPage(page)
    if not self.undo[page] then self:Notify("本页没有可撤销的随机结果。", "warning"); return end
    self.draft = self.undo[page]; self.undo[page] = nil; self:Render(); self:Notify("已撤销本页随机。", "success")
end

function App:AddMember()
    local id = self.draft.nextId; self.draft.nextId = id + 1
    table.insert(self.draft.members, { id = id, name = self.draft.family .. "新", sex = "女", age = 18, parents = {}, spouseId = nil, talent = 2, focus = "general", experienceId = "none", trait = "沉静", jobId = "farm" })
    self:Render()
end

function App:RemoveMember(memberId)
    if #self.draft.members <= 1 then self:Notify("至少保留一位族人。", "warning"); return end
    local member = State.FindMember(self.draft.members, memberId)
    if memberId == self.draft.leaderId then self:Notify("请先指定另一位成年首任族长。", "warning"); return end
    for index, item in ipairs(self.draft.members) do if item.id == memberId then table.remove(self.draft.members, index); break end end
    for _, item in ipairs(self.draft.members) do
        if item.spouseId == memberId then item.spouseId = nil end
        local nextParents = {}; for _, parentId in ipairs(item.parents) do if parentId ~= memberId then table.insert(nextParents, parentId) end end; item.parents = nextParents
    end
    self:Render(); self:Notify("已移除“" .. member.name .. "”，关联关系已重新校验。", "success")
end

function App:StartRun()
    local run, issues = State.NewRun(self.draft, self.profile)
    if not run then self:Notify(table.concat(issues, " "), "error"); return end
    self.run = run; self.gameTab = "family"; self:Save(); self:Render(); self:Notify("家谱开篇。每一年的安排都会留下痕迹。", "success")
end

function App:RunAction(fn)
    if self.actionBusy then
        self:Notify("上一项安排正在写入，请勿重复操作。", "warning")
        return
    end
    self.actionBusy = true
    local ok, message = fn()
    self.actionBusy = false
    if ok then self:Save(); self:Render(); self:Notify(message, "success") else self:Notify(message, "warning") end
end

function App:BuildHeader(title, subtitle)
    return UI.Panel {
        height = 62, flexDirection = "row", alignItems = "center", justifyContent = "space-between", paddingHorizontal = 16,
        backgroundColor = C.paper, borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            UI.Panel { flexDirection = "column", pointerEvents = "none", children = { Label(title, { fontSize = 25, fontWeight = "bold", fontColor = C.green }), Label(subtitle, { fontSize = 11, fontColor = C.muted }) } },
            Button("存档", function() self:Save() end, { width = 62, height = 36, fontSize = 12, backgroundColor = C.pale, textColor = C.green }),
        },
    }
end

function App:BuildOpeningFooter()
    local order = { world = "世道", people = "族人", estate = "家底", relics = "信物", final = "落笔" }
    local pages = { "world", "people", "estate", "relics", "final" }
    local index = 1; for i, page in ipairs(pages) do if page == self.openingPage then index = i end end
    local total = State.TotalPoints(self.draft)
    return UI.Panel {
        flexDirection = "column", backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, padding = 10, gap = 7,
        children = {
            Label("总分 " .. tostring(total) .. "/100" .. (total > 100 and " · 超分草案可继续编辑，但不能开局" or " · 自由组合，无需用尽"), { fontSize = 12, fontColor = total > 100 and C.warning or C.muted, textAlign = "center" }),
            UI.Row { gap = 8, children = {
                index > 1 and Button("上一步", function() self:SetOpeningPage(pages[index - 1]) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }) or UI.Box(1, 1),
                index < #pages and Button("下一步", function() self:SetOpeningPage(pages[index + 1]) end, { flex = 1 }) or Button("开始家业", function() self:StartRun() end, { flex = 1, backgroundColor = total > 100 and C.warning or C.green }),
            } },
        },
    }
end

function App:BuildOpeningNav()
    local pages = { { id = "world", text = "世道" }, { id = "people", text = "族人" }, { id = "estate", text = "家底" }, { id = "relics", text = "信物" }, { id = "final", text = "落笔" } }
    local children = {}
    for _, page in ipairs(pages) do
        table.insert(children, Button(page.text, function() self:SetOpeningPage(page.id) end, { flex = 1, height = 34, fontSize = 11, backgroundColor = self.openingPage == page.id and C.green or C.pale, textColor = self.openingPage == page.id and { 255, 255, 255, 255 } or C.green }))
    end
    return UI.Panel { padding = 10, backgroundColor = C.paper, children = { UI.Row { gap = 4, children = children } } }
end

function App:BuildOptionList(items, selectedId, onSelect, description)
    local children = {}
    for _, item in ipairs(items) do
        local active = item.id == selectedId
        local detail = item.desc or ""
        if item.burden then detail = detail .. "\n" .. item.burden end
        table.insert(children, Button((active and "✓ " or "") .. item.name .. " · " .. tostring(item.cost or 0) .. " 点\n" .. detail, function()
            onSelect(item.id)
        end, {
            height = item.burden and 76 or 60,
            backgroundColor = active and C.green or C.card,
            textColor = active and { 255, 255, 255, 255 } or C.ink,
            borderColor = active and C.green or C.line,
            borderWidth = 1,
            textAlign = "left",
            paddingHorizontal = 12,
            fontSize = 13,
        }))
    end
    return UI.Panel { gap = 9, children = children }
end

function App:BuildWorldPage()
    local period = Data.Period(self.draft.periodId)
    local years = {}
    for _, year in ipairs(period.years) do table.insert(years, Button(tostring(year) .. " 年", function() self.draft.calendar = year; self:Render() end, { flex = 1, height = 38, backgroundColor = self.draft.calendar == year and C.green or C.pale, textColor = self.draft.calendar == year and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    local used, capacity = State.PageBudget(self.draft, "world")
    return UI.Panel { gap = 12, children = {
        Card({ Label("世道与来处", { fontSize = 21, fontWeight = "bold" }), Label("本页 " .. tostring(used) .. "/" .. tostring(math.max(0, capacity)) .. " 点 · 时期与年份联动，年份不重复收费。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
            Label("家姓", { fontSize = 13 }), UI.Row { gap = 8, children = {
                UI.TextField { value = self.draft.family, placeholder = "请输入姓氏", fontSize = 16, flex = 1, onChange = function(_, value) self.draft.family = value ~= "" and value or "林"; self:UpdatePreview() end },
                Button("随机", function() self:RandomFamilyName() end, { width = 72, height = 40, backgroundColor = C.pale, textColor = C.green, fontSize = 12 }),
            } },
            Label("开局时期", { fontSize = 13, fontWeight = "bold" }), self:BuildOptionList(Data.Periods, self.draft.periodId, function(id) self:SelectPeriod(id) end),
            Label("当前时期可选年份 · 推导时世：" .. period.name, { fontSize = 13, fontColor = C.muted }), UI.Row { gap = 6, children = years },
        }),
        Card({ Label("来历", { fontSize = 18, fontWeight = "bold" }), self:BuildOptionList(Data.Origins, self.draft.originId, function(id) self.draft.originId = id; self:Render() end) }),
        Card({ Label("落脚地区", { fontSize = 18, fontWeight = "bold" }), self:BuildOptionList(Data.Places, self.draft.placeId, function(id) self.draft.placeId = id; self:Render() end) }),
    } }
end

function App:BuildPeoplePage()
    local used, capacity = State.PageBudget(self.draft, "people")
    local cards = { Card({ Label("家中这些人", { fontSize = 21, fontWeight = "bold" }), Label("本页 " .. tostring(used) .. "/" .. tostring(math.max(0, capacity)) .. " 点。每个人都能独立查看与安排。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), Button("添加族人", function() self:AddMember() end, { height = 38 }) }) }
    for _, member in ipairs(self.draft.members) do
        local talentIndex = tonumber(member.talent) or 1
        local talent = Data.Talent(talentIndex)
        local experience = Data.Experience(member.experienceId)
        table.insert(cards, Card({
            UI.Row { justifyContent = "space-between", children = { Label(member.name .. " · " .. tostring(member.age) .. " 岁", { fontSize = 17, fontWeight = "bold" }), Label(member.id == self.draft.leaderId and "首任族长" or "", { fontSize = 12, fontColor = C.green }) } },
            Label("" .. talent.name .. " · " .. experience.name .. " · " .. Data.Jobs[member.jobId].name .. " · " .. tostring(State.MemberCost(member)) .. " 点", { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
            UI.Row { gap = 8, children = { Button("查看与编辑", function() self:OpenDraftMember(member.id) end, { flex = 1, height = 38 }), Button("设为族长", function() self.draft.leaderId = member.id; self:Render() end, { flex = 1, height = 38, backgroundColor = C.pale, textColor = C.green }) } },
        }))
    end
    return UI.Panel { gap = 10, children = cards }
end

function App:OpenDraftMember(memberId)
    local original = State.FindMember(self.draft.members, memberId)
    if not original then return end
    local editing = State.Copy(original)
    local modal = UI.Modal { title = editing.name .. " · 编辑", size = "fullscreen", closeOnOverlay = false, onClose = function(selfModal) selfModal:Destroy() end }
    local nameField = UI.TextField { value = editing.name, flex = 1, onChange = function(_, value) if value ~= "" then editing.name = value end end }
    local content = UI.ScrollView { height = "70%", flexBasis = 0, padding = 14, children = { UI.Panel { gap = 10, children = {
        Label("姓名", { fontSize = 13 }), UI.Row { gap = 8, children = {
            nameField,
            Button("随机姓名", function()
                editing.name = self:RandomName(editing.sex)
                nameField:SetValue(editing.name)
            end, { width = 92, height = 40, backgroundColor = C.pale, textColor = C.green, fontSize = 12 }),
        } },
        Label("年龄：" .. tostring(editing.age), { fontSize = 13 }), UI.Stepper { value = editing.age, min = 0, max = 92, step = 1, onChange = function(_, value) editing.age = math.floor(value) end },
        Label("资质", { fontSize = 13, fontWeight = "bold" }),
    } } } }
    for index, talent in ipairs(Data.Talents) do content:GetChildAt(1):AddChild(Button(talent.name .. " · " .. tostring(talent.cost) .. " 点", function() editing.talent = index; self:Notify("已在临时预览中选择“" .. talent.name .. "”。") end, { height = 34, backgroundColor = editing.talent == index and C.green or C.pale, textColor = editing.talent == index and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    content:GetChildAt(1):AddChild(Label("已有本领", { fontSize = 13, fontWeight = "bold" }))
    for _, experience in ipairs(Data.Experiences) do content:GetChildAt(1):AddChild(Button(experience.name .. " · " .. tostring(experience.cost) .. " 点", function() editing.experienceId = experience.id; self:Notify("已在临时预览中选择“" .. experience.name .. "”。") end, { height = 34, backgroundColor = editing.experienceId == experience.id and C.green or C.pale, textColor = editing.experienceId == experience.id and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    modal:AddContent(content)
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("移除", function() modal:Close(); self:RemoveMember(memberId) end, { flex = 1, backgroundColor = C.warning }),
        Button("取消", function() modal:Close() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        Button("保存", function() for index, item in ipairs(self.draft.members) do if item.id == memberId then self.draft.members[index] = editing end end; modal:Close(); self:Render(); self:Notify("人物编辑已保存。", "success") end, { flex = 1 }),
    } })
    modal:Open()
end

function App:BuildEstatePage()
    local used, capacity = State.PageBudget(self.draft, "estate")
    local homeButtons = {}
    for _, home in ipairs(Data.Homes) do table.insert(homeButtons, Button(home.name .. " · " .. tostring(home.cost) .. " 点", function() self.draft.homeId = home.id; self:Render() end, { height = 38, backgroundColor = self.draft.homeId == home.id and C.green or C.pale, textColor = self.draft.homeId == home.id and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    local habitButtons = {}; for _, habit in ipairs(Data.Habits) do table.insert(habitButtons, Button(habit.name .. " · " .. tostring(habit.cost) .. " 点", function() self.draft.habitId = habit.id; self:Render() end, { height = 36, backgroundColor = self.draft.habitId == habit.id and C.green or C.pale, textColor = self.draft.habitId == habit.id and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    local tieButtons = {}; for _, tie in ipairs(Data.Ties) do table.insert(tieButtons, Button(tie.name .. " · " .. tostring(tie.cost) .. " 点", function() self.draft.tieId = tie.id; self:Render() end, { height = 36, backgroundColor = self.draft.tieId == tie.id and C.green or C.pale, textColor = self.draft.tieId == tie.id and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    return UI.Panel { gap = 12, children = {
        Card({ Label("安身家底", { fontSize = 21, fontWeight = "bold" }), Label("本页 " .. tostring(used) .. "/" .. tostring(math.max(0, capacity)) .. " 点。初始家底与每年收益分开结算。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
            Label("现银 " .. tostring(self.draft.money) .. " 两（每 10 两 1 点）", { fontSize = 14 }), UI.Stepper { value = self.draft.money, min = 0, max = 300, step = 10, onChange = function(_, value) self.draft.money = math.floor(value); self:UpdatePreview() end },
            Label("存粮 " .. tostring(self.draft.grain) .. " 石（每 4 石 1 点）", { fontSize = 14 }), UI.Stepper { value = self.draft.grain, min = 0, max = 160, step = 4, onChange = function(_, value) self.draft.grain = math.floor(value); self:UpdatePreview() end },
            Label("田地 " .. tostring(self.draft.land) .. " 亩（每亩 4 点）", { fontSize = 14 }), UI.Stepper { value = self.draft.land, min = 0, max = 12, step = 1, onChange = function(_, value) self.draft.land = math.floor(value); self:UpdatePreview() end },
        }),
        Card({ Label("住宅", { fontSize = 18, fontWeight = "bold" }), UI.Panel { gap = 6, children = homeButtons } }),
        Card({ Label("产业", { fontSize = 18, fontWeight = "bold" }), UI.Toggle { checked = self.draft.workshop, onChange = function(_, value) self.draft.workshop = value; self:Render() end }, Label("木工作坊 · 14 点 · 需要手艺人经营才有收益", { fontSize = 13, fontColor = C.muted }), UI.Toggle { checked = self.draft.shop, onChange = function(_, value) self.draft.shop = value; self:Render() end }, Label("小商铺 · 20 点 · 需要经商族人经营才有收益", { fontSize = 13, fontColor = C.muted }) }),
        Card({ Label("家风", { fontSize = 18, fontWeight = "bold" }), UI.Panel { gap = 6, children = habitButtons }, Label("往来关系", { fontSize = 18, fontWeight = "bold", marginTop = 8 }), UI.Panel { gap = 6, children = tieButtons } }),
    } }
end

function App:BuildRelicPage()
    local used, capacity = State.PageBudget(self.draft, "relics")
    local cards = { Card({ Label("随身旧物", { fontSize = 21, fontWeight = "bold" }), Label("本页 " .. tostring(used) .. "/" .. tostring(math.max(0, capacity)) .. " 点。解锁资格与本局实体分开，带入可多选。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }) }) }
    for _, relic in ipairs(Data.Relics) do
        local unlocked = self.profile.unlockedRelicIds[relic.id]
        local selected = false; for _, id in ipairs(self.draft.selectedRelicIds) do if id == relic.id then selected = true end end
        table.insert(cards, Card({ Label(relic.name .. " · " .. tostring(relic.cost) .. " 点", { fontSize = 17, fontWeight = "bold", fontColor = unlocked and C.ink or C.muted }), Label(relic.desc, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.5 }),
            unlocked and Button(selected and "已带入" or "带入本局", function() self:ToggleRelic(relic.id) end, { height = 38, backgroundColor = selected and C.green or C.pale, textColor = selected and { 255, 255, 255, 255 } or C.green }) or Label("尚未解锁 · 可在凡世经历中寻找线索", { fontSize = 12, fontColor = C.warning }),
        }, { borderColor = selected and C.green or C.line, backgroundColor = unlocked and C.card or { 239, 238, 232, 255 } }))
    end
    return UI.Panel { gap = 10, children = cards }
end

function App:BuildFinalPage()
    local total = State.TotalPoints(self.draft); local issues = State.ValidateDraft(self.draft, self.profile, false)
    local groups = State.PointGroups(self.draft)
    local rows = { Label("世道 " .. tostring(groups.world) .. " 点", { fontSize = 14 }), Label("族人 " .. tostring(groups.people) .. " 点", { fontSize = 14 }), Label("家底 " .. tostring(groups.estate) .. " 点", { fontSize = 14 }), Label("信物 " .. tostring(groups.relics) .. " 点", { fontSize = 14 }) }
    local issueLabels = {}; for _, issue in ipairs(issues) do table.insert(issueLabels, Label("• " .. issue, { fontSize = 13, fontColor = C.warning, whiteSpace = "normal" })) end
    local issueWidget = #issueLabels > 0 and UI.Panel { gap = 6, children = issueLabels } or Label("草案有效。未花完的点数不会自动兑换成家财。", { fontSize = 13, fontColor = C.muted })
    local startButton = Button(total <= 100 and "开始这一局" or "超分，返回调整", function()
        self:StartRun()
    end, { backgroundColor = total <= 100 and C.green or C.warning })
    local summaryCard = Card({
        Label("落笔之前", { fontSize = 21, fontWeight = "bold" }),
        Label(self.draft.family .. "氏 · 大晟历 " .. tostring(self.draft.calendar) .. " 年 · " .. Data.Period(self.draft.periodId).name, { fontSize = 14, fontColor = C.muted }),
        UI.Panel { gap = 6, children = rows },
        UI.Divider { color = C.line },
        Label("总计 " .. tostring(total) .. "/100 点", { fontSize = 24, fontWeight = "bold", fontColor = total > 100 and C.warning or C.green }),
        issueWidget,
        startButton,
    })
    local backupActions = UI.Row { gap = 8, children = {
        Button("写入备份", function() self:Export() end, { flex = 1, height = 38 }),
        Button("读取最近存档", function() self:Load() end, { flex = 1, height = 38, backgroundColor = C.pale, textColor = C.green }),
    } }
    local backupCard = Card({
        Label("本地备份", { fontSize = 18, fontWeight = "bold" }),
        Label("存档仅属于当前项目与当前用户；可生成 JSON 备份，换设备时请自行带回。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
        backupActions,
    })
    return UI.Panel { gap = 12, children = { summaryCard, backupCard } }
end

function App:BuildOpening()
    local builders = { world = function() return self:BuildWorldPage() end, people = function() return self:BuildPeoplePage() end, estate = function() return self:BuildEstatePage() end, relics = function() return self:BuildRelicPage() end, final = function() return self:BuildFinalPage() end }
    local page = self.openingPage
    local pageActions = UI.Row { gap = 8, children = {
        Button("随机本页", function() self:RandomizePage(page) end, { flex = 1, height = 36, backgroundColor = C.pale, textColor = C.green, fontSize = 12 }),
        Button("撤销随机", function() self:UndoPage(page) end, { flex = 1, height = 36, backgroundColor = C.pale, textColor = C.green, fontSize = 12 }),
    } }
    local pageContent = UI.Panel { gap = 12, children = { pageActions, builders[page]() } }
    local scroll = UI.ScrollView { flexGrow = 1, flexBasis = 0, padding = 12, children = { pageContent } }
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.paper, flexDirection = "column", children = {
        self:BuildHeader("家业", "凡世王朝 · 开局立谱"),
        self:BuildOpeningNav(),
        scroll,
        self:BuildOpeningFooter(),
    } }
end

function App:BuildGameNav()
    local tabs = { { id = "family", text = "家族" }, { id = "people", text = "族人" }, { id = "estate", text = "家业" }, { id = "relics", text = "藏阁" }, { id = "history", text = "家史" } }
    local children = {}
    for _, tab in ipairs(tabs) do table.insert(children, Button(tab.text, function() self.gameTab = tab.id; self:Render() end, { flex = 1, height = 42, fontSize = 12, backgroundColor = self.gameTab == tab.id and C.pale or C.card, textColor = self.gameTab == tab.id and C.green or C.muted })) end
    return UI.Panel { padding = 7, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = { UI.Row { gap = 3, children = children } } }
end

function App:BuildPendingEvent(event)
    if event.type == "relic_resolution" then
        local instance = nil; for _, item in ipairs(self.run.relicInstances) do if item.instanceId == event.relicInstanceId then instance = item end end
        local relic = instance and Data.Relic(instance.definitionId)
        local restore = Button("修复并落笔", function()
            self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "restore", self.profile) end)
        end, { flex = 1 })
        local defer = Button("暂存线索", function()
            self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "defer", self.profile) end)
        end, { flex = 1, backgroundColor = C.pale, textColor = C.green })
        local actions = UI.Row { gap = 8, children = { restore, defer } }
        return Card({
            Label(event.title, { fontSize = 19, fontWeight = "bold" }),
            Label("“" .. (relic and relic.name or "旧物") .. "”的调查到期。修复会写入家史，并按路线解锁下一局资格。", { fontSize = 14, whiteSpace = "normal", lineHeight = 1.6 }),
            actions,
        }, { borderColor = C.green })
    end
    if event.type == "leader" then
        local choices = {}; for _, member in ipairs(self.run.members) do if member.alive and member.age >= 18 then table.insert(choices, Button("任命 " .. member.name, function() self:RunAction(function() return Simulation.ResolveLeaderEvent(self.run, event.instanceId, member.id) end) end, { height = 38 })) end end
        return Card({ Label("族长之位空缺", { fontSize = 19, fontWeight = "bold" }), Label("家族仍可继续，但需要从在世成年族人中选任族长。", { fontSize = 14, whiteSpace = "normal" }), UI.Panel { gap = 6, children = choices } }, { borderColor = C.warning })
    end
    return Card({ Label(event.title, { fontSize = 18, fontWeight = "bold" }) })
end

function App:BuildFamilyTab()
    local leader = State.FindMember(self.run.members, self.run.leaderId)
    local living = 0; for _, member in ipairs(self.run.members) do if member.alive then living = living + 1 end end
    local pending = Simulation.PendingEvents(self.run)
    local completedEnding = TableValue(self.run.ending)
    local endingTitle = completedEnding["title"] or "从这一年，慢慢过成一个家。"
    local hero = Card({
        Label("家族第 " .. tostring(self.run.yearIndex + 1) .. " 年 · " .. Data.WORLD_NAME .. "历 " .. tostring(self.run.calendar) .. " 年", { fontSize = 13, fontColor = C.muted }),
        Label(tostring(endingTitle), { fontSize = 25, fontWeight = "bold", whiteSpace = "normal", lineHeight = 1.45, fontColor = { 255, 254, 250, 255 } }),
        Label("族长：" .. (leader and leader.name or "暂缺") .. " · " .. Data.Place(self.run.placeId).short, { fontSize = 14, fontColor = { 226, 235, 220, 255 } }),
    }, { backgroundColor = C.dark, borderColor = C.dark })
    local metrics = UI.Row { justifyContent = "space-between", children = {
        Label("在世族人\n" .. tostring(living) .. " 人", { fontSize = 14, whiteSpace = "normal" }),
        Label("公库\n" .. tostring(self.run.money) .. " 两", { fontSize = 14, whiteSpace = "normal" }),
        Label("存粮\n" .. tostring(self.run.grain) .. " 石", { fontSize = 14, whiteSpace = "normal" }),
        Label("声望\n" .. tostring(self.run.reputation), { fontSize = 14, whiteSpace = "normal" }),
    } }
    local children = { hero, Card({ metrics }) }
    if self.run.ending then table.insert(children, Card({ Label("本局已落笔", { fontSize = 18, fontWeight = "bold" }), Label(tostring(completedEnding["summary"] or "这段家史已被妥善收录。"), { fontSize = 14, whiteSpace = "normal" }), Button("新立家谱", function() self.run = nil; self.draft = State.NewDraft(); self.openingPage = "world"; self:Render() end, { height = 40 }) }))
    elseif #pending > 0 then for _, event in ipairs(pending) do table.insert(children, self:BuildPendingEvent(event)) end
    else table.insert(children, Card({ Label("这一年的安排已经保留", { fontSize = 18, fontWeight = "bold" }), Label("年度推进会按年初在世成员的主业结算收入、粮食、成长与人生变化。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), Button("推进这一年 →", function() self:RunAction(function() return Simulation.AdvanceYear(self.run, self.profile) end) end) })) end
    return UI.Panel { gap = 12, children = children }
end

function App:OpenRunMember(memberId)
    local member = State.FindMember(self.run.members, memberId); if not member then return end
    local modal = UI.Modal { title = member.name .. " · " .. tostring(member.age) .. " 岁", size = "fullscreen", closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end }
    local content = UI.ScrollView { height = "70%", flexBasis = 0, padding = 14, children = { UI.Panel { gap = 9, children = {
        Label(member.alive and "当前主业：" .. Data.Jobs[member.jobId].name or "已故 · 生平可读", { fontSize = 17, fontWeight = "bold" }), Label("学识 " .. tostring(member.stats.learn) .. " · 手艺 " .. tostring(member.stats.skill) .. " · 医术 " .. tostring(member.stats.medicine) .. " · 经营 " .. tostring(member.stats.trade) .. " · 武艺 " .. tostring(member.stats.martial), { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
        Label("人生安排", { fontSize = 16, fontWeight = "bold", marginTop = 6 }),
    } } } }
    if member.alive and not self.run.ending then
        for jobId, job in pairs(Data.Jobs) do
            local ok, reason = Simulation.GetJobReason(member, jobId)
            content:GetChildAt(1):AddChild(Button(job.name .. (ok and "" or " · " .. reason), function() self:RunAction(function() return Simulation.SetJob(self.run, memberId, jobId) end); modal:Close() end, { height = 36, backgroundColor = ok and (member.jobId == jobId and C.green or C.pale) or { 235, 229, 224, 255 }, textColor = ok and (member.jobId == jobId and { 255, 255, 255, 255 } or C.green) or C.warning, fontSize = 11 }))
        end
        content:GetChildAt(1):AddChild(Button("应试（10 两）", function() self:RunAction(function() return Simulation.TakeExam(self.run, memberId) end); modal:Close() end, { height = 38 }))
        content:GetChildAt(1):AddChild(Button("安排婚配（12 两）", function() self:RunAction(function() return Simulation.Marry(self.run, memberId) end); modal:Close() end, { height = 38, backgroundColor = C.pale, textColor = C.green }))
        content:GetChildAt(1):AddChild(Button("收养孩子（8 两）", function() self:RunAction(function() return Simulation.Adopt(self.run, memberId) end); modal:Close() end, { height = 38, backgroundColor = C.pale, textColor = C.green }))
        content:GetChildAt(1):AddChild(Button("任命为族长", function() self:RunAction(function() return Simulation.AppointLeader(self.run, memberId, "主动交接") end); modal:Close() end, { height = 38, backgroundColor = C.pale, textColor = C.green }))
    end
    content:GetChildAt(1):AddChild(Label("经历", { fontSize = 16, fontWeight = "bold", marginTop = 8 }))
    for _, line in ipairs(member.biography) do content:GetChildAt(1):AddChild(Label("• " .. line, { fontSize = 13, whiteSpace = "normal", fontColor = C.muted })) end
    modal:AddContent(content); modal:SetFooter(Button("返回", function() modal:Close() end, { height = 40 })); modal:Open()
end

function App:BuildPeopleTab()
    local cards = { Card({ Label("全体族人", { fontSize = 21, fontWeight = "bold" }), Label("所有成员都可独立安排；死亡不会从家谱中删除。", { fontSize = 13, fontColor = C.muted }) }) }
    for _, member in ipairs(self.run.members) do table.insert(cards, Card({ UI.Row { justifyContent = "space-between", children = { Label(member.name .. " · " .. tostring(member.age) .. " 岁", { fontSize = 17, fontWeight = "bold", fontColor = member.alive and C.ink or C.muted }), Label(member.id == self.run.leaderId and "族长" or (member.alive and "" or "已故"), { fontSize = 12, fontColor = C.green }) } }, Label(member.alive and Data.Jobs[member.jobId].name or "生平已封存", { fontSize = 13, fontColor = C.muted }), Button(member.alive and "查看与安排" or "阅读生平", function() self:OpenRunMember(member.id) end, { height = 38 }) })) end
    return UI.Panel { gap = 10, children = cards }
end

function App:BuildEstateTab()
    local placeButtons = {}
    for _, place in ipairs(Data.Places) do
        local placeId = place.id
        table.insert(placeButtons, Button("迁居 " .. place.short .. "\n" .. place.desc .. " " .. place.burden, function()
            self:RunAction(function() return Simulation.MoveFamily(self.run, placeId) end)
        end, {
            height = 66,
            backgroundColor = self.run.placeId == placeId and C.green or C.pale,
            textColor = self.run.placeId == placeId and { 255, 255, 255, 255 } or C.green,
            textAlign = "left",
            paddingHorizontal = 12,
            fontSize = 12,
        }))
    end
    local purchaseActions = UI.Row { gap = 7, children = {
        Button("购田 30 两", function() self:RunAction(function() return Simulation.BuyAsset(self.run, "land") end) end, { flex = 1, height = 38 }),
        Button("作坊 80 两", function() self:RunAction(function() return Simulation.BuyAsset(self.run, "workshop") end) end, { flex = 1, height = 38 }),
        Button("商铺 120 两", function() self:RunAction(function() return Simulation.BuyAsset(self.run, "shop") end) end, { flex = 1, height = 38 }),
    } }
    local estateCard = Card({
        Label("家业与公库", { fontSize = 21, fontWeight = "bold" }),
        Label("银 " .. tostring(self.run.money) .. " 两 · 粮 " .. tostring(self.run.grain) .. " 石 · 田 " .. tostring(self.run.land) .. " 亩", { fontSize = 16 }),
        Label("作坊：" .. (self.run.workshop and "已有（需手艺人经营）" or "未置办") .. "\n商铺：" .. (self.run.shop and "已有（需经商者经营）" or "未置办"), { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
        purchaseActions,
        Button("接济邻里（15 两）", function() self:RunAction(function() return Simulation.AidCommunity(self.run) end) end, { height = 38, backgroundColor = C.pale, textColor = C.green }),
    })
    local moveCard = Card({
        Label("迁居", { fontSize = 18, fontWeight = "bold" }),
        Label("迁居会写入真实年份和费用，不会把家人折叠成不可操作支系。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
        UI.Panel { gap = 6, children = placeButtons },
    })
    return UI.Panel { gap = 12, children = {
        estateCard,
        moveCard,
    } }
end

function App:BuildRelicsTab()
    local cards = { Card({ Label("藏阁", { fontSize = 21, fontWeight = "bold" }), Label("这里是本局实际物件。已解锁目录只决定下一局可选择的内容。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }) }) }
    for _, instance in ipairs(self.run.relicInstances) do
        local relic = Data.Relic(instance.definitionId); local custodian = State.FindMember(self.run.members, instance.custodianId)
        ---@type Widget
        local actions = nil
        actions = Label("已出售 · 历史和局外资格仍会保留。", { fontSize = 13, fontColor = C.warning })
        if instance.status ~= "sold" then
            actions = UI.Row { gap = 6, children = {
                Button("快查", function() self:RunAction(function() return Simulation.StartRelicInvestigation(self.run, instance.instanceId, "fast") end) end, { flex = 1, height = 36 }),
                Button("慢查", function() self:RunAction(function() return Simulation.StartRelicInvestigation(self.run, instance.instanceId, "slow") end) end, { flex = 1, height = 36, backgroundColor = C.pale, textColor = C.green }),
                Button("出售", function() self:RunAction(function() return Simulation.SellRelic(self.run, instance.instanceId) end) end, { flex = 1, height = 36, backgroundColor = C.warning }),
            } }
        end
        table.insert(cards, Card({ Label(relic.name, { fontSize = 18, fontWeight = "bold" }), Label("状态：" .. instance.status .. " · 保管人：" .. (custodian and custodian.name or "家中"), { fontSize = 13, fontColor = C.muted }), actions,
        }))
    end
    if #self.run.relicInstances == 0 then table.insert(cards, Card({ Label("本局没有带入旧物。", { fontSize = 15, fontColor = C.muted }) })) end
    return UI.Panel { gap = 10, children = cards }
end

function App:BuildHistoryTab()
    local endingCards = {}
    for _, ending in ipairs(Data.Endings) do
        local progress = Simulation.EndingProgress(self.run, ending.id); local lines, ready = {}, true
        for _, item in ipairs(progress) do table.insert(lines, item[1] .. " " .. tostring(item[2]) .. "/" .. tostring(item[3])); if item[2] < item[3] then ready = false end end
        ---@type Widget
        local action = nil
        action = Label(ready and "已达成资格" or "仍可探索", { fontSize = 12, fontColor = ready and C.green or C.muted })
        if ready and not self.run.ending then
            action = Button("以此落笔", function()
                self:RunAction(function() return Simulation.ClaimEnding(self.run, ending.id, self.profile) end)
            end, { height = 36 })
        end
        table.insert(endingCards, Card({
            Label(ending.title, { fontSize = 17, fontWeight = "bold" }),
            Label(table.concat(lines, " · "), { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
            action,
        }))
    end
    local logCards = {}; for _, log in ipairs(self.run.logs) do table.insert(logCards, Label("大晟历 " .. tostring(log.year) .. " 年 · " .. log.text, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.5 })) end
    return UI.Panel { gap = 12, children = { Card({ Label("家史", { fontSize = 21, fontWeight = "bold" }), Label("历代族长、年鉴与终章均保留真实发生的事实。", { fontSize = 13, fontColor = C.muted }) }), Card({ Label("可探索的终章", { fontSize = 18, fontWeight = "bold" }), UI.Panel { gap = 8, children = endingCards } }), Card({ Label("年鉴", { fontSize = 18, fontWeight = "bold" }), UI.Panel { gap = 8, children = logCards } }) } }
end

function App:BuildGame()
    local builders = { family = function() return self:BuildFamilyTab() end, people = function() return self:BuildPeopleTab() end, estate = function() return self:BuildEstateTab() end, relics = function() return self:BuildRelicsTab() end, history = function() return self:BuildHistoryTab() end }
    local openingSnapshot = TableValue(self.run.openingSnapshot)
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.paper, flexDirection = "column", children = {
        self:BuildHeader("家业", tostring(openingSnapshot["family"] or "无名") .. "氏家谱 · " .. Data.Place(self.run.placeId).short),
        UI.ScrollView { flexGrow = 1, flexBasis = 0, padding = 12, children = { builders[self.gameTab]() } }, self:BuildGameNav(),
    } }
end

function App:Render()
    local page = self.run and self:BuildGame() or self:BuildOpening()
    local phoneFrame = UI.Panel {
        width = "100%",
        maxWidth = 480,
        height = "100%",
        backgroundColor = C.paper,
        overflow = "hidden",
        children = { page },
    }
    self.root = UI.SafeAreaView {
        width = "100%",
        height = "100%",
        edges = "all",
        backgroundColor = C.dark,
        alignItems = "center",
        children = { phoneFrame },
    }
    UI.SetRoot(self.root, true)
end

return App
