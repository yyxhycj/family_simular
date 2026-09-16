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
    if props.fontSize then props.fontSize = math.max(10, math.floor(props.fontSize * 0.85)) end
    return UI.Label(props)
end

local function Button(text, onClick, props)
    props = props or {}; props.text = text; props.onClick = onClick; props.height = props.height or 40
    props.backgroundColor = props.backgroundColor or C.green; props.textColor = props.textColor or { 255, 255, 255, 255 }
    props.borderRadius = props.borderRadius or 8
    if props.fontSize then props.fontSize = math.max(10, math.floor(props.fontSize * 0.9)) end
    return UI.Button(props)
end

local function Card(children, props)
    props = props or {}; props.backgroundColor = props.backgroundColor or C.card; props.borderColor = props.borderColor or C.line
    props.borderWidth = props.borderWidth or 1; props.borderRadius = props.borderRadius or 10; props.padding = props.padding or 11; props.gap = props.gap or 7
    props.flexDirection = "column"; props.children = children
    return UI.Panel(props)
end

---@param value unknown
---@return table<any, any>
local function TableValue(value)
    return type(value) == "table" and value or {}
end

local function HasId(values, id)
    for _, value in ipairs(values or {}) do if value == id then return true end end
    return false
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
    self.screen = "cover"
    self.openingPage = "world"
    self.gameTab = "family"
    self.undo = {}
    self.root = nil
    self.previewLabel = nil
    self.peopleFilter = "all"
    self.peopleQuery = ""
    self.openingFeedback = ""
    UI.Toast.GetGlobal({ position = "bottom", maxToasts = 1 })
end

function App:Notify(message, variant)
    local toast = UI.Toast.GetGlobal()
    toast:DismissAll()
    UI.Toast.Show(message, { variant = variant or "info", duration = 2.2, showClose = false })
end

function App:Save()
    local ok, message = State.Save(self.profile, self.draft, self.run)
    self:Notify(message, ok and "success" or "error")
end

function App:Load()
    local value, message = State.Load()
    if not value then self:Notify(message, "warning"); return end
    if type(value.profile) == "table" and type(value.draft) == "table" then
        value.profile.unlockedRelicIds = value.profile.unlockedRelicIds or { book = true, ruler = true, letter = true }
        value.profile.endingRecords = value.profile.endingRecords or {}
        self.profile, self.draft, self.run = value.profile, value.draft, value.run
        self.screen = self.run and "game" or "opening"
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

function App:RandomName(sex, surname)
    local surnames = Data.Surnames
    local givenNames = Data.GivenNames[sex == "男" and "male" or "female"]
    return (surname or surnames[self:Random(#surnames)]) .. givenNames[self:Random(#givenNames)]
end

function App:RandomFamilyName(draft)
    local target = draft or self.draft
    local oldFamily = target.family
    local nextFamily = Data.Surnames[self:Random(#Data.Surnames)]
    target.family = nextFamily
    for _, member in ipairs(target.members) do
        if member.name:sub(1, #oldFamily) == oldFamily then
            member.name = nextFamily .. member.name:sub(#oldFamily + 1)
        end
    end
    if not draft then self:Render() end
end

function App:UpdatePreview()
    if self.previewLabel then
        local total = State.TotalPoints(self.draft)
        self.previewLabel:SetText(self.draft.family .. "氏家谱 · " .. tostring(#self.draft.members) .. " 人 · " .. tostring(total) .. "/100 点")
    end
end

function App:SetOpeningPage(page)
    self.openingPage = page
    self.openingFeedback = ""
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

function App:EligibleExperiences(member)
    local job, choices = Data.Jobs[member.jobId], {}
    if not job or member.age < job.min then return choices end
    for _, experience in ipairs(Data.Experiences) do
        local childAllowed = member.age >= 18 or experience.id == "none" or experience.id == "basic"
        local requirementMet = not job.req or (experience.values[job.req[1]] or 0) >= job.req[2]
        if childAllowed and requirementMet then table.insert(choices, experience) end
    end
    return choices
end

function App:IsPlayableDraft(candidate)
    return #State.ValidateDraft(candidate, self.profile, false) == 0
end

function App:SafeRandomPage(before, page)
    local candidate = State.Copy(before)
    if page == "world" then
        candidate.periodId = "unrest"; candidate.calendar = Data.Period("unrest").years[1]
        candidate.originId = "plain"; candidate.placeId = "village"
        self:RandomFamilyName(candidate)
    elseif page == "people" then
        for _, member in ipairs(candidate.members) do
            member.talent = 1
            local choices = self:EligibleExperiences(member)
            table.sort(choices, function(a, b) return a.cost < b.cost end)
            if not choices[1] then return nil end
            member.experienceId = choices[1].id
            local surname = member.name:sub(1, #candidate.family) == candidate.family and candidate.family or nil
            member.name = self:RandomName(member.sex, surname)
        end
    elseif page == "estate" then
        candidate.money = 0; candidate.grain = 0; candidate.land = 0
        candidate.homeId = "rented"; candidate.workshop = false; candidate.shop = false
        candidate.habitId = "none"; candidate.tieId = "none"
    elseif page == "relics" then
        candidate.selectedRelicIds = {}
    end
    return self:IsPlayableDraft(candidate) and candidate or nil
end

function App:RandomizePage(page)
    local before = State.Copy(self.draft)
    local generated = false
    for _ = 1, 120 do
        local candidate = State.Copy(before)
        if page == "world" then
            local period = Data.Periods[self:Random(#Data.Periods)]
            candidate.periodId = period.id; candidate.calendar = period.years[self:Random(#period.years)]
            candidate.originId = Data.Origins[self:Random(#Data.Origins)].id; candidate.placeId = Data.Places[self:Random(#Data.Places)].id
        elseif page == "people" then
            for _, member in ipairs(candidate.members) do
                member.talent = self:Random(#Data.Talents)
                local choices = self:EligibleExperiences(member)
                if #choices == 0 then break end
                member.experienceId = choices[self:Random(#choices)].id
            end
        elseif page == "estate" then
            candidate.money = (self:Random(10) - 1) * 10; candidate.grain = (self:Random(10) - 1) * 4; candidate.land = self:Random(4) - 1
            candidate.homeId = Data.Homes[self:Random(#Data.Homes)].id; candidate.workshop = self:Random(2) == 1; candidate.shop = self:Random(2) == 1
            candidate.habitId = Data.Habits[self:Random(#Data.Habits)].id; candidate.tieId = Data.Ties[self:Random(#Data.Ties)].id
        elseif page == "relics" then
            candidate.selectedRelicIds = {}
            for relicId in pairs(self.profile.unlockedRelicIds) do if self:Random(2) == 1 then table.insert(candidate.selectedRelicIds, relicId) end end
        end
        if self:IsPlayableDraft(candidate) then
            if page == "world" then
                self:RandomFamilyName(candidate)
            elseif page == "people" then
                for _, member in ipairs(candidate.members) do
                    local surname = member.name:sub(1, #candidate.family) == candidate.family and candidate.family or nil
                    member.name = self:RandomName(member.sex, surname)
                end
            end
            candidate.rngSeed = self.draft.rngSeed
            self.draft = candidate; generated = true; break
        end
    end
    if not generated then
        local fallback = self:SafeRandomPage(before, page)
        if fallback then
            fallback.rngSeed = self.draft.rngSeed
            self.draft = fallback; generated = true
        end
    end
    if generated then
        self.undo[page] = before
        self.openingFeedback = "已随机本页：总分 " .. tostring(State.TotalPoints(self.draft)) .. "/100，仍可直接开局。"
    else
        self.openingFeedback = "这一页没有可开局的新组合；先减少其他页的点数后再试。"
    end
    self:Render()
end

function App:UndoPage(page)
    if not self.undo[page] then self:Notify("本页没有可撤销的随机结果。", "warning"); return end
    self.draft = self.undo[page]; self.undo[page] = nil; self.openingFeedback = "已恢复随机前的本页配置。"; self:Render()
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
    self.run = run; self.screen = "game"; self.gameTab = "family"; self:Save(); self:Render(); self:Notify("家谱开篇。每一年的安排都会留下痕迹。", "success")
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
        height = 54, flexDirection = "row", alignItems = "center", justifyContent = "space-between", paddingHorizontal = 12,
        backgroundColor = C.paper, borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            UI.Panel { flexDirection = "column", pointerEvents = "none", children = { Label(title, { fontSize = 22, fontWeight = "bold", fontColor = C.green }), Label(subtitle, { fontSize = 10, fontColor = C.muted }) } },
            Button("存档", function() self:Save() end, { width = 56, height = 32, fontSize = 11, backgroundColor = C.pale, textColor = C.green }),
        },
    }
end

function App:GetRunOverview()
    local living, foodNeed = 0, 0
    for _, member in ipairs(self.run.members) do
        if member.alive then
            living = living + 1
            foodNeed = foodNeed + (member.age >= 18 and 2 or 1)
        end
    end
    return living, foodNeed
end

function App:BuildRunStatusBar()
    local living, foodNeed = self:GetRunOverview()
    local foodUnsafe = self.run.grain < foodNeed
    local function metric(name, value, color)
        return UI.Panel {
            flex = 1, height = 42, paddingHorizontal = 6, justifyContent = "center",
            backgroundColor = C.card, borderWidth = 1, borderColor = color or C.line, borderRadius = 7,
            children = {
                Label(name, { fontSize = 10, fontColor = C.muted }),
                Label(value, { fontSize = 14, fontWeight = "bold", fontColor = color or C.ink }),
            },
        }
    end
    return UI.Panel {
        paddingHorizontal = 8, paddingVertical = 6, gap = 4, backgroundColor = C.pale, borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            Label("第 " .. tostring(self.run.yearIndex + 1) .. " 年 · " .. Data.WORLD_NAME .. "历 " .. tostring(self.run.calendar) .. " 年 · " .. tostring(living) .. " 人在世", { fontSize = 10, fontColor = C.muted }),
            UI.Row { gap = 4, children = {
                metric("公库", tostring(self.run.money) .. " 两"),
                metric("存粮", tostring(self.run.grain) .. "/" .. tostring(foodNeed) .. " 石", foodUnsafe and C.warning or nil),
                metric("田地", tostring(self.run.land) .. " 亩"),
                metric("声望", tostring(self.run.reputation)),
            } },
        },
    }
end

function App:BuildOpeningFooter()
    local pages = { "world", "people", "estate", "relics", "final" }
    local index = 1; for i, page in ipairs(pages) do if page == self.openingPage then index = i end end
    local total = State.TotalPoints(self.draft)
    return UI.Panel {
        flexDirection = "column", backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, padding = 8, gap = 5,
        children = {
            Label("总分 " .. tostring(total) .. "/100" .. (total > 100 and " · 超分，暂不能开局" or " · 可直接开局"), { fontSize = 11, fontColor = total > 100 and C.warning or C.muted, textAlign = "center" }),
            UI.Row { gap = 8, children = {
                index > 1 and Button("上一步", function() self:SetOpeningPage(pages[index - 1]) end, { flex = 1, height = 36, backgroundColor = C.pale, textColor = C.green }) or UI.Box(1, 1),
                index < #pages and Button("下一步", function() self:SetOpeningPage(pages[index + 1]) end, { flex = 1, height = 36 }) or Button("开始家业", function() self:StartRun() end, { flex = 1, height = 36, backgroundColor = total > 100 and C.warning or C.green }),
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
    return UI.Panel { padding = 6, backgroundColor = C.paper, children = { UI.Row { gap = 4, children = children } } }
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
            height = item.burden and 64 or 50,
            backgroundColor = active and C.green or C.card,
            textColor = active and { 255, 255, 255, 255 } or C.ink,
            borderColor = active and C.green or C.line,
            borderWidth = 1,
            textAlign = "left",
            paddingHorizontal = 10,
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
    local cards = { Card({ Label("家中这些人", { fontSize = 21, fontWeight = "bold" }), Label("本页 " .. tostring(used) .. "/" .. tostring(math.max(0, capacity)) .. " 点。每个人都能独立查看与安排。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), Button("添加族人", function() self:AddMember() end, { height = 34 }) }) }
    for _, member in ipairs(self.draft.members) do
        local talentIndex = tonumber(member.talent) or 1
        local talent = Data.Talent(talentIndex)
        local experience = Data.Experience(member.experienceId)
        table.insert(cards, Card({
            UI.Row { justifyContent = "space-between", children = { Label(member.name .. " · " .. tostring(member.age) .. " 岁", { fontSize = 17, fontWeight = "bold" }), Label(member.id == self.draft.leaderId and "首任族长" or "", { fontSize = 12, fontColor = C.green }) } },
            Label("" .. talent.name .. " · " .. experience.name .. " · " .. Data.Jobs[member.jobId].name .. " · " .. tostring(State.MemberCost(member)) .. " 点", { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
            UI.Row { gap = 8, children = { Button("查看与编辑", function() self:OpenDraftMember(member.id) end, { flex = 1, height = 34 }), Button("设为族长", function() self.draft.leaderId = member.id; self:Render() end, { flex = 1, height = 34, backgroundColor = C.pale, textColor = C.green }) } },
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
        Label("亲缘与婚配", { fontSize = 16, fontWeight = "bold", marginTop = 6 }),
        Label("亲缘在保存时校验年龄差与循环；婚配必须双方成年。", { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
        Label("资质", { fontSize = 13, fontWeight = "bold" }),
    } } } }
    local panel = content:GetChildAt(1)
    for _, candidate in ipairs(self.draft.members) do
        if candidate.id ~= editing.id and candidate.age - editing.age >= 18 then
            panel:AddChild(Button((HasId(editing.parents, candidate.id) and "✓ " or "") .. "设为父母/养亲：" .. candidate.name, function()
                if HasId(editing.parents, candidate.id) then
                    local nextParents = {}; for _, id in ipairs(editing.parents) do if id ~= candidate.id then table.insert(nextParents, id) end end; editing.parents = nextParents
                elseif #editing.parents < 2 then
                    table.insert(editing.parents, candidate.id)
                else self:Notify("最多可设两位父母/养亲。", "warning") end
            end, { height = 34, backgroundColor = HasId(editing.parents, candidate.id) and C.green or C.pale, textColor = HasId(editing.parents, candidate.id) and { 255, 255, 255, 255 } or C.green, fontSize = 12 }))
        end
    end
    for _, candidate in ipairs(self.draft.members) do
        if candidate.id ~= editing.id and candidate.age >= 18 and editing.age >= 18 then
            panel:AddChild(Button((editing.spouseId == candidate.id and "✓ " or "") .. "设为配偶：" .. candidate.name, function()
                editing.spouseId = editing.spouseId == candidate.id and nil or candidate.id
                self:Notify("婚配将在保存时双向写入并校验。", "info")
            end, { height = 34, backgroundColor = editing.spouseId == candidate.id and C.green or C.pale, textColor = editing.spouseId == candidate.id and { 255, 255, 255, 255 } or C.green, fontSize = 12 }))
        end
    end
    for index, talent in ipairs(Data.Talents) do panel:AddChild(Button(talent.name .. " · " .. tostring(talent.cost) .. " 点", function() editing.talent = index; self:Notify("已在临时预览中选择“" .. talent.name .. "”。") end, { height = 34, backgroundColor = editing.talent == index and C.green or C.pale, textColor = editing.talent == index and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    panel:AddChild(Label("已有本领", { fontSize = 13, fontWeight = "bold" }))
    for _, experience in ipairs(Data.Experiences) do panel:AddChild(Button(experience.name .. " · " .. tostring(experience.cost) .. " 点", function() editing.experienceId = experience.id; self:Notify("已在临时预览中选择“" .. experience.name .. "”。") end, { height = 34, backgroundColor = editing.experienceId == experience.id and C.green or C.pale, textColor = editing.experienceId == experience.id and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    modal:AddContent(content)
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("移除", function() modal:Close(); self:RemoveMember(memberId) end, { flex = 1, backgroundColor = C.warning }),
        Button("取消", function() modal:Close() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        Button("保存", function()
            for _, item in ipairs(self.draft.members) do if item.spouseId == memberId then item.spouseId = nil end end
            if editing.spouseId then
                local spouse = State.FindMember(self.draft.members, editing.spouseId)
                if spouse then
                    if spouse.spouseId then local former = State.FindMember(self.draft.members, spouse.spouseId); if former then former.spouseId = nil end end
                    spouse.spouseId = memberId
                end
            end
            for index, item in ipairs(self.draft.members) do if item.id == memberId then self.draft.members[index] = editing end end
            modal:Close(); self:Render(); self:Notify("人物与关系编辑已保存。", "success")
        end, { flex = 1 }),
    } })
    modal:Open()
end

function App:BuildEstatePage()
    local used, capacity = State.PageBudget(self.draft, "estate")
    local homeButtons = {}
    for _, home in ipairs(Data.Homes) do table.insert(homeButtons, Button(home.name .. " · " .. tostring(home.cost) .. " 点", function() self.draft.homeId = home.id; self:Render() end, { height = 38, backgroundColor = self.draft.homeId == home.id and C.green or C.pale, textColor = self.draft.homeId == home.id and { 255, 255, 255, 255 } or C.green, fontSize = 12 })) end
    local habitButtons = {}; for _, habit in ipairs(Data.Habits) do table.insert(habitButtons, Button(habit.name .. " · " .. tostring(habit.cost) .. " 点\n" .. habit.desc, function() self.draft.habitId = habit.id; self:Render() end, { height = 52, backgroundColor = self.draft.habitId == habit.id and C.green or C.pale, textColor = self.draft.habitId == habit.id and { 255, 255, 255, 255 } or C.green, fontSize = 12, textAlign = "left", paddingHorizontal = 10 })) end
    local tieButtons = {}; for _, tie in ipairs(Data.Ties) do table.insert(tieButtons, Button(tie.name .. " · " .. tostring(tie.cost) .. " 点\n" .. tie.desc, function() self.draft.tieId = tie.id; self:Render() end, { height = 52, backgroundColor = self.draft.tieId == tie.id and C.green or C.pale, textColor = self.draft.tieId == tie.id and { 255, 255, 255, 255 } or C.green, fontSize = 12, textAlign = "left", paddingHorizontal = 10 })) end
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

function App:BuildCover()
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.dark, justifyContent = "center", padding = 26, children = {
        UI.Panel { gap = 16, children = {
            Label("家业", { fontSize = 42, fontWeight = "bold", fontColor = { 255, 254, 250, 255 } }),
            Label("一部由选择写成的家谱", { fontSize = 18, fontColor = { 226, 235, 220, 255 } }),
            Label("立一户人家，过一年算一年。有人出生、有人离去，手艺、声望与旧物都会留在家史里。", { fontSize = 15, fontColor = { 226, 235, 220, 255 }, whiteSpace = "normal", lineHeight = 1.65, marginTop = 12 }),
            Button("立一部家谱", function() self.screen = "opening"; self:Render() end, { height = 52, fontSize = 17, marginTop = 20 }),
            Button("读取最近存档", function() self:Load() end, { height = 46, backgroundColor = C.pale, textColor = C.green }),
        } },
    } }
end

function App:BuildOpening()
    local builders = { world = function() return self:BuildWorldPage() end, people = function() return self:BuildPeoplePage() end, estate = function() return self:BuildEstatePage() end, relics = function() return self:BuildRelicPage() end, final = function() return self:BuildFinalPage() end }
    local page = self.openingPage
    local pageActions = UI.Row { gap = 8, children = {
        Button("随机本页", function() self:RandomizePage(page) end, { flex = 1, height = 32, backgroundColor = C.pale, textColor = C.green, fontSize = 11 }),
        Button("撤销随机", function() self:UndoPage(page) end, { flex = 1, height = 32, backgroundColor = C.pale, textColor = C.green, fontSize = 11 }),
    } }
    local pageChildren = { pageActions }
    if self.openingFeedback ~= "" then table.insert(pageChildren, Label(self.openingFeedback, { fontSize = 11, fontColor = C.green, backgroundColor = C.pale, padding = 8, borderRadius = 8, whiteSpace = "normal" })) end
    table.insert(pageChildren, builders[page]())
    local pageContent = UI.Panel { gap = 8, children = pageChildren }
    local scroll = UI.ScrollView { flexGrow = 1, flexBasis = 0, padding = 8, children = { pageContent } }
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
    for _, tab in ipairs(tabs) do table.insert(children, Button(tab.text, function() self.gameTab = tab.id; self:Render() end, { flex = 1, height = 36, fontSize = 11, backgroundColor = self.gameTab == tab.id and C.pale or C.card, textColor = self.gameTab == tab.id and C.green or C.muted })) end
    return UI.Panel { padding = 5, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = { UI.Row { gap = 3, children = children } } }
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
    local details = {
        medical_find = "医馆愿意把一册珍贵的批注医案托付给家中。收下后，它会真实进入本局藏阁，并解锁下一局。",
        plan_work = "有人看中了旧营造图。备好工料接下活计，可换得净收益与声望。",
        jade_search = "半枚玉佩传来新的去向。付路费查访，或把线索留待以后。",
        school = "孩子的求学机会就在眼前。添置书本会让所有未成年族人增长学识。",
        community_request = "邻里手头困难，是否拿出家中余钱周转？",
        roof = "雨季将近，屋顶的破损需要决定是否现在修补。",
        notes_choice = "医案已经到手。可以花钱刊印，也可以郑重地传给后人。",
    }
    local actions = nil
    if event.type == "medical_find" then
        actions = UI.Row { gap = 8, children = {
            Button("收下医案", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "accept", self.profile) end) end, { flex = 1 }),
            Button("暂不收下", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "decline", self.profile) end) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "plan_work" then
        actions = UI.Row { gap = 8, children = {
            Button("接下修缮", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "accept", self.profile) end) end, { flex = 1 }),
            Button("婉拒", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "decline", self.profile) end) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "jade_search" then
        actions = UI.Row { gap = 8, children = {
            Button("查访（8 两）", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "search", self.profile) end) end, { flex = 1 }),
            Button("暂存", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "defer", self.profile) end) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "school" then
        actions = UI.Row { gap = 8, children = {
            Button("添书（6 两）", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "support", self.profile) end) end, { flex = 1 }),
            Button("暂缓", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "decline", self.profile) end) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "community_request" then
        actions = UI.Row { gap = 8, children = {
            Button("接济（15 两）", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "aid", self.profile) end) end, { flex = 1 }),
            Button("婉拒", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "decline", self.profile) end) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "roof" then
        actions = UI.Row { gap = 8, children = {
            Button("修补（8 两）", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "repair", self.profile) end) end, { flex = 1 }),
            Button("暂缓", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "decline", self.profile) end) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "notes_choice" then
        actions = UI.Row { gap = 8, children = {
            Button("刊印（8 两）", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "print", self.profile) end) end, { flex = 1 }),
            Button("传给后人", function() self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, "pass", self.profile) end) end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    end
    if actions then return Card({ Label(event.title, { fontSize = 19, fontWeight = "bold" }), Label(details[event.type] or "需要你的决定。", { fontSize = 14, whiteSpace = "normal", lineHeight = 1.55 }), actions }, { borderColor = C.green }) end
    return Card({ Label(event.title, { fontSize = 18, fontWeight = "bold" }) })
end

function App:BuildFamilyTab()
    local leader = State.FindMember(self.run.members, self.run.leaderId)
    local _, foodNeed = self:GetRunOverview()
    local pending = Simulation.PendingEvents(self.run)
    local completedEnding = TableValue(self.run.ending)
    local title = completedEnding["title"] or (self.run.yearIndex == 0 and "第一年，先把这一家安顿好" or "这一年，家里的事由你决定")
    local hero = Card({
        Label("第 " .. tostring(self.run.yearIndex + 1) .. " 年 · " .. Data.WORLD_NAME .. "历 " .. tostring(self.run.calendar) .. " 年", { fontSize = 11, fontColor = { 226, 235, 220, 255 } }),
        Label(tostring(title), { fontSize = 20, fontWeight = "bold", whiteSpace = "normal", lineHeight = 1.3, fontColor = { 255, 254, 250, 255 } }),
        Label("族长 " .. (leader and leader.name or "暂缺") .. " · " .. Data.Place(self.run.placeId).short, { fontSize = 12, fontColor = { 226, 235, 220, 255 } }),
    }, { backgroundColor = C.dark, borderColor = C.dark })
    local children = { hero }
    if self.run.ending then
        table.insert(children, Card({ Label("本局已落笔", { fontSize = 17, fontWeight = "bold" }), Label(tostring(completedEnding["summary"] or "这段家史已被妥善收录。"), { fontSize = 12, whiteSpace = "normal" }), Button("新立家谱", function() self.run = nil; self.screen = "opening"; self.draft = State.NewDraft(); self.openingPage = "world"; self:Render() end, { height = 36 }) }))
    elseif #pending > 0 then
        table.insert(children, Card({ Label("先处理眼前这件事", { fontSize = 16, fontWeight = "bold" }), Label("事件处理后，才能结算下一年。", { fontSize = 11, fontColor = C.muted }) }))
        for _, event in ipairs(pending) do table.insert(children, self:BuildPendingEvent(event)) end
    else
        local firstYear = self.run.yearIndex == 0
        local guidance = firstYear and "先看每位族人的主业；如果手艺人或经商者没有产业，再到“家业”页置办。确认后，点底部“推进这一年”。" or (self.run.grain < foodNeed and "粮食不足以覆盖这一年：先在“族人”页安排耕作，或到“家业”页购粮、置办田地。" or "本年已有安排。你可以微调族人主业、置办家业，或直接推进年度结算。")
        table.insert(children, Card({
            Label(firstYear and "第一年这样开始" or "这一年的优先事项", { fontSize = 16, fontWeight = "bold" }),
            Label(guidance, { fontSize = 12, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
            UI.Row { gap = 7, children = {
                Button("安排族人", function() self.gameTab = "people"; self:Render() end, { flex = 1, height = 34, backgroundColor = C.pale, textColor = C.green, fontSize = 11 }),
                Button("查看家业", function() self.gameTab = "estate"; self:Render() end, { flex = 1, height = 34, backgroundColor = C.pale, textColor = C.green, fontSize = 11 }),
            } },
        }))
        local arrangements = { Label("本年安排", { fontSize = 16, fontWeight = "bold" }), Label("点一位族人即可改主业、婚配或安排传承。", { fontSize = 11, fontColor = C.muted }) }
        for _, member in ipairs(self.run.members) do
            if member.alive then
                table.insert(arrangements, Button(member.name .. " · " .. Data.Jobs[member.jobId].name .. " · " .. tostring(member.age) .. " 岁", function() self:OpenRunMember(member.id) end, { height = 32, backgroundColor = C.pale, textColor = C.green, textAlign = "left", paddingHorizontal = 10, fontSize = 11 }))
            end
        end
        table.insert(children, Card(arrangements))
    end
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
        content:GetChildAt(1):AddChild(Button(member.birthPlan == false and "愿意迎来孩子" or "暂不计划生育", function()
            self:RunAction(function() return Simulation.SetBirthPlan(self.run, memberId, member.birthPlan == false) end); modal:Close()
        end, { height = 38, backgroundColor = C.pale, textColor = C.green }))
        content:GetChildAt(1):AddChild(Button("任命为族长", function() self:RunAction(function() return Simulation.AppointLeader(self.run, memberId, "主动交接") end); modal:Close() end, { height = 38, backgroundColor = C.pale, textColor = C.green }))
    end
    for _, relic in ipairs(self.run.relicInstances) do
        if relic.status ~= "sold" and relic.custodianId ~= memberId and member.alive then
            local definition = Data.Relic(relic.definitionId)
            content:GetChildAt(1):AddChild(Button("交由" .. member.name .. "保管 · " .. definition.name, function()
                self:RunAction(function() return Simulation.TransferRelic(self.run, relic.instanceId, memberId) end); modal:Close()
            end, { height = 36, backgroundColor = C.pale, textColor = C.green, fontSize = 12 }))
        end
    end
    content:GetChildAt(1):AddChild(Label("经历", { fontSize = 16, fontWeight = "bold", marginTop = 8 }))
    for _, line in ipairs(member.biography) do content:GetChildAt(1):AddChild(Label("• " .. line, { fontSize = 13, whiteSpace = "normal", fontColor = C.muted })) end
    modal:AddContent(content); modal:SetFooter(Button("返回", function() modal:Close() end, { height = 40 })); modal:Open()
end

function App:BuildPeopleTab()
    local cards = { Card({ Label("全体族人", { fontSize = 21, fontWeight = "bold" }), Label("所有成员都可独立安排；死亡不会从家谱中删除。", { fontSize = 13, fontColor = C.muted }),
        UI.Row { gap = 5, children = {
            Button("全部", function() self.peopleFilter = "all"; self:Render() end, { flex = 1, height = 34, fontSize = 11, backgroundColor = self.peopleFilter == "all" and C.green or C.pale, textColor = self.peopleFilter == "all" and { 255, 255, 255, 255 } or C.green }),
            Button("在世", function() self.peopleFilter = "alive"; self:Render() end, { flex = 1, height = 34, fontSize = 11, backgroundColor = self.peopleFilter == "alive" and C.green or C.pale, textColor = self.peopleFilter == "alive" and { 255, 255, 255, 255 } or C.green }),
            Button("已故", function() self.peopleFilter = "dead"; self:Render() end, { flex = 1, height = 34, fontSize = 11, backgroundColor = self.peopleFilter == "dead" and C.green or C.pale, textColor = self.peopleFilter == "dead" and { 255, 255, 255, 255 } or C.green }),
        } },
        UI.TextField { value = self.peopleQuery, placeholder = "按姓名筛选", onChange = function(_, value) self.peopleQuery = value; self:Render() end },
    }) }
    for _, member in ipairs(self.run.members) do
        local visible = self.peopleFilter == "all" or (self.peopleFilter == "alive" and member.alive) or (self.peopleFilter == "dead" and not member.alive)
        visible = visible and (self.peopleQuery == "" or string.find(member.name, self.peopleQuery, 1, true) ~= nil)
        if visible then table.insert(cards, Card({ UI.Row { justifyContent = "space-between", children = { Label(member.name .. " · " .. tostring(member.age) .. " 岁", { fontSize = 17, fontWeight = "bold", fontColor = member.alive and C.ink or C.muted }), Label(member.id == self.run.leaderId and "族长" or (member.alive and "" or "已故"), { fontSize = 12, fontColor = C.green }) } }, Label(member.alive and Data.Jobs[member.jobId].name or "生平已封存", { fontSize = 13, fontColor = C.muted }), Button(member.alive and "查看与安排" or "阅读生平", function() self:OpenRunMember(member.id) end, { height = 38 }) })) end
    end
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
            local actionChildren = {
                Button("快查", function() self:RunAction(function() return Simulation.StartRelicInvestigation(self.run, instance.instanceId, "fast") end) end, { flex = 1, height = 36 }),
                Button("慢查", function() self:RunAction(function() return Simulation.StartRelicInvestigation(self.run, instance.instanceId, "slow") end) end, { flex = 1, height = 36, backgroundColor = C.pale, textColor = C.green }),
                Button("出售", function() self:RunAction(function() return Simulation.SellRelic(self.run, instance.instanceId) end) end, { flex = 1, height = 36, backgroundColor = C.warning }),
            }
            actions = UI.Panel { gap = 6, children = { UI.Row { gap = 6, children = actionChildren } } }
            if relic.id == "newbook" then
                actions:AddChild(Button("邀请成年旁支归家（12 两）", function() self:RunAction(function() return Simulation.InviteBranch(self.run, instance.instanceId) end) end, { height = 36, backgroundColor = C.pale, textColor = C.green, fontSize = 12 }))
            end
        end
        table.insert(cards, Card({ Label(relic.name, { fontSize = 18, fontWeight = "bold" }), Label("状态：" .. instance.status .. " · 保管人：" .. (custodian and custodian.name or "家中"), { fontSize = 13, fontColor = C.muted }), actions,
        }))
    end
    if #self.run.relicInstances == 0 then table.insert(cards, Card({ Label("本局没有带入旧物。", { fontSize = 15, fontColor = C.muted }) })) end
    return UI.Panel { gap = 10, children = cards }
end

function App:BuildAnnualFooter()
    if self.run.ending then return nil end
    local pending = Simulation.PendingEvents(self.run)
    if #pending > 0 then return UI.Panel { padding = 8, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = { Label("有待决事件 · 请先在家族页作出决定", { textAlign = "center", fontSize = 12, fontColor = C.warning }) } } end
    return UI.Panel { padding = 8, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = {
        Button("推进这一年", function() self:RunAction(function() return Simulation.AdvanceYear(self.run, self.profile) end) end, { height = 40, fontSize = 14 }),
    } }
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
    local children = {
        self:BuildHeader("家业", tostring(openingSnapshot["family"] or "无名") .. "氏家谱 · " .. Data.Place(self.run.placeId).short),
        self:BuildRunStatusBar(),
        UI.ScrollView { flexGrow = 1, flexBasis = 0, padding = 12, children = { builders[self.gameTab]() } },
    }
    local annualFooter = self:BuildAnnualFooter()
    if annualFooter then table.insert(children, annualFooter) end
    table.insert(children, self:BuildGameNav())
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.paper, flexDirection = "column", children = children }
end

function App:Render()
    local page = self.screen == "cover" and self:BuildCover() or (self.run and self:BuildGame() or self:BuildOpening())
    local phoneFrame = UI.Panel {
        width = "100%",
        maxWidth = 430,
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
