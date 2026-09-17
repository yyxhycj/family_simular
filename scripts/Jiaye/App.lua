local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Opening = require "Jiaye.Opening"
local OpeningView = require "Jiaye.OpeningView"

local App = {}
App.__index = App

local C = {
    paper = { 245, 243, 237, 255 }, card = { 255, 254, 250, 255 }, ink = { 38, 60, 51, 255 },
    muted = { 97, 107, 99, 255 }, line = { 221, 222, 218, 255 }, green = { 55, 99, 77, 255 },
    dark = { 45, 78, 59, 255 }, pale = { 232, 239, 221, 255 }, warning = { 164, 78, 56, 255 },
}

local ROUTE_GUIDANCE = {
    peaceful = { tab = "people", button = "安排族人", hint = "让家中有人能持续承担事务，并在合适的时候完成交接。" },
    scholar = { tab = "people", button = "安排读书", hint = "培养不同代的族人走向读书、教书或任职。" },
    merchant = { tab = "people", button = "安排经商", hint = "让族人稳定经商，再用积蓄置办产业。" },
    craft = { tab = "estate", button = "查看家业", hint = "培养手艺人，并让作坊真正有人经营。" },
    medical = { tab = "people", button = "安排学医", hint = "让不同代族人积累医术，接过医者的生活。" },
    grain = { tab = "estate", button = "经营田产", hint = "安排耕作、添置田地，把一家人的粮食留到冬天以后。" },
    community = { tab = "estate", button = "经营家业", hint = "先稳住家底，再在乡里需要时承担责任。" },
    migration = { tab = "estate", button = "查看迁居", hint = "选定新的落脚处，带着家人把日子重新安稳下来。" },
    ["return"] = { tab = "people", button = "安排护卫", hint = "让一位族人走出家门，也在合适时回到家中。" },
    promise = { tab = "relics", button = "查看信物", hint = "从家中旧物与线索里，继续完成前人留下的承诺。" },
    ruler = { tab = "relics", button = "查看信物", hint = "让老木尺的线索和手艺人的经历真正汇成家业。" },
    reunion = { tab = "relics", button = "查看信物", hint = "保留并修复族谱，让一次真实交接写进家史。" },
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
    self.openingView = "summary"
    self.gameTab = "family"
    self.undo = {}
    self.root = nil
    self.previewLabel = nil
    self.peopleFilter = "all"
    self.peopleQuery = ""
    self.openingFeedback = ""
    self.openingGenerationFailed = false
    self.historyPage = 1
    self.unsaved = false
    self.saveMessage = ""
    local saved, message, status = State.Load()
    if saved then self.profile, self.draft, self.run = saved.profile, saved.draft, saved.run end
    self.storageBlocked = status == "invalid"
    if status == "invalid" or status == "recovered" then self.saveMessage = message end
    if not saved and not self.storageBlocked then
        local draft, issue = Opening.Generate(self.profile, Opening.FreshSeed(), "mortal")
        if draft then
            self.draft = draft; self.screen = "opening"
        else
            self.openingGenerationFailed = true
            self.openingFeedback = issue or "暂未生成合法家庭，请重试。"
        end
    end
    UI.Toast.GetGlobal({ position = "bottom", maxToasts = 1 })
end

function App:Notify(message, variant)
    local toast = UI.Toast.GetGlobal()
    toast:DismissAll()
    UI.Toast.Show(message, { variant = variant or "info", duration = 2.2, showClose = false })
end

function App:Save()
    if self.storageBlocked then self:Notify(self.saveMessage, "error"); return false end
    -- 试配新家庭期间，手动存档仍保存旧局的草案；取消不会把候选写进旧局。
    local ok, message = State.Save(self.profile, self.previousDraft or self.draft, self.run)
    self.unsaved = not ok; self.saveMessage = ok and "" or message
    self:Render()
    self:Notify(message, ok and "success" or "error")
    return ok
end

function App:Load()
    if self.unsaved then self:Notify("当前安排尚未保存，请先重试保存或导出，避免丢失。", "warning"); return end
    local value, message, status = State.Load()
    if not value then self:Notify(message, "warning"); return end
    self.profile, self.draft, self.run = value.profile, value.draft, value.run
    self.previousDraft = nil; self.editBackup = nil; self.houseUndo = nil; self.openingView = "summary"; self.undo = {}; self.historyPage = 1; self.storageBlocked = false; self.openingGenerationFailed = false
    self.saveMessage = status == "recovered" and message or ""
    self.screen = self.run and "game" or "opening"
    self:Render(); self:Notify(message, status == "recovered" and "warning" or "success")
end

function App:Export()
    local raw, message = State.Export(self.profile, self.previousDraft or self.draft, self.run)
    self:Notify(message, raw and "success" or "error")
end

function App:SetDraftField(page, key, value)
    self.draft[key] = value; self.undo[page] = nil; self.houseUndo = nil
    self.openingFeedback = ""; self:Render()
end

-- 所有真正写入草案的手改都统一从这里经过：当前页的旧随机结果随即失效。
function App:MarkOpeningPageChanged(page)
    self.undo[page] = nil
    self.houseUndo = nil
    self.openingFeedback = ""
end

function App:RandomFamilyName()
    local ok, message = Opening.RandomFamilyName(self.draft)
    if ok then self.undo.people = nil; self.houseUndo = nil end
    self.openingFeedback = message; self:Render()
end

function App:RandomizePage(page)
    local before = Opening.Snapshot(self.draft, page)
    local candidate, issue = Opening.RandomPage(self.draft, page, self.profile)
    if candidate then
        self.draft = candidate
        self.undo[page] = { before = before, after = Opening.Snapshot(candidate, page) }
        self.houseUndo = nil
        self.openingFeedback = "已随机本页，可撤销；其他页保持不变。"
    else self.openingFeedback = issue end
    self:Render()
end

function App:UndoPage(page)
    local undo = self.undo[page]
    if not undo or not Opening.Equal(Opening.Snapshot(self.draft, page), undo.after) then
        self.undo[page] = nil; self.openingFeedback = "本页已修改或没有可撤销结果，草案保持不变。"
    else
        Opening.Restore(self.draft, page, undo.before); self.undo[page] = nil
        self.openingFeedback = "已撤销本页随机，其他页保持不变。"
    end
    self:Render()
end

function App:ChangeHouse()
    local candidate, issue = Opening.Generate(self.profile, self.draft.rngSeed, self.draft.worldId)
    if candidate then
        self.houseUndo = State.Copy(self.draft); self.draft = candidate; self.undo = {}
        self.openingFeedback = "已换一家；可恢复上一家，包括此前手改内容。"
    else self.openingFeedback = issue end
    self:Render()
end

function App:UndoHouse()
    if not self.houseUndo then return end
    self.draft = self.houseUndo; self.houseUndo = nil; self.undo = {}
    self.openingFeedback = "已恢复上一家。"; self:Render()
end

function App:BeginOpeningEdit(page)
    if not self.editBackup then self.editBackup = State.Copy(self.draft); self.editUndo = State.Copy(self.undo) end
    self.openingView = "editor"; self.openingPage = page or "world"; self.openingFeedback = ""; self:Render()
end

function App:OpenOpeningDetail(view)
    self.openingReturn = self.openingView or "summary"
    self.openingView = view
    self.openingFeedback = ""
    self:Render()
end

function App:ReturnOpeningDetail()
    self.openingView = self.openingReturn or "summary"
    self.openingReturn = nil
    self.openingFeedback = ""
    self:Render()
end

function App:FinishOpeningEdit(save)
    if save then
        local issues = State.ValidateDraft(self.draft, self.profile, true)
        if #issues > 0 then self.openingFeedback = table.concat(issues, "\n"); self:Render(); return false end
    elseif self.editBackup then self.draft = self.editBackup; self.undo = self.editUndo or {} end
    self.editBackup = nil; self.editUndo = nil; self.houseUndo = nil
    self.openingView = "summary"; self.openingFeedback = ""; self:Render()
    return true
end

function App:SaveOpeningDraft()
    -- 编辑中的字段先通过“保存并返回”校验；校验失败时仍留在编辑器，绝不写入半成品。
    if not self:FinishOpeningEdit(true) then return false end
    return self:Save()
end

function App:SetOpeningPage(page)
    self.openingPage = page; self.openingFeedback = ""; self:Render()
end

function App:SelectPeriod(id)
    self.draft.calendar = Data.Period(id).years[1]
    self:SetDraftField("world", "periodId", id)
end

function App:ToggleRelic(id)
    local selected = State.Copy(self.draft.selectedRelicIds)
    local found = false
    for index, value in ipairs(selected) do if value == id then table.remove(selected, index); found = true; break end end
    if not found then table.insert(selected, id) end
    self:SetDraftField("relics", "selectedRelicIds", selected)
end

function App:AddMember()
    -- 新成员只存在于人物编辑副本，取消时绝不改变成员列表或 nextId。
    local id = self.draft.nextId
    self.memberIsNew = true
    self.memberEditing = { id = id, name = self.draft.family .. "新", nameSource = "family", givenName = "新", sex = "女",
        age = 18, parents = {}, talent = 2, focus = "general", experienceId = "none", trait = "沉静", jobId = "farm" }
    self.memberLeader = self.draft.leaderId
    self.memberReturn = self.openingView
    self.memberSection = "base"; self.memberIssue = ""; self.removeConfirm = false
    self.openingView = "member"; self:Render()
end

function App:RemoveMember(memberId)
    if #self.draft.members <= 1 then self.memberIssue = "至少保留一位族人。"; self:Render(); return end
    for index, member in ipairs(self.draft.members) do if member.id == memberId then table.remove(self.draft.members, index); break end end
    for _, member in ipairs(self.draft.members) do
        if member.spouseId == memberId then member.spouseId = nil end
        local parents = {}; for _, id in ipairs(member.parents) do if id ~= memberId then table.insert(parents, id) end end
        member.parents = parents
    end
    self.undo.people = nil; self.houseUndo = nil; self.memberEditing = nil; self.memberIsNew = nil; self.removeConfirm = false
    self.openingView = self.memberReturn or "summary"
    self.openingFeedback = "已移除成员并清理关系引用；如移除了首任族长，请另行指定。"; self:Render()
end

function App:OpenDraftMember(memberId)
    local member = State.FindMember(self.draft.members, memberId)
    if not member then return end
    self.memberEditing = State.Copy(member); self.memberIsNew = false; self.memberLeader = self.draft.leaderId
    self.memberReturn = self.openingView; self.memberSection = "base"; self.memberIssue = ""; self.removeConfirm = false
    self.openingView = "member"; self:Render()
end

-- 预览和保存共用同一份候选草案；新成员尚未写入 draft 时也按最终形态计分和校验。
function App:DraftMemberCandidate()
    local candidate, issue
    if self.memberIsNew then
        candidate = State.Copy(self.draft)
        table.insert(candidate.members, State.Copy(self.memberEditing))
        candidate.nextId = math.max(candidate.nextId or 1, self.memberEditing.id + 1)
        -- 复用编辑命令，使新增人物与既有成员完全同样处理双向婚配和旧配偶解绑。
        candidate, issue = Opening.EditMember(candidate, self.memberEditing, self.memberLeader, self.profile)
    else
        candidate, issue = Opening.EditMember(self.draft, self.memberEditing, self.memberLeader, self.profile)
    end
    return candidate, issue
end

function App:SaveDraftMember()
    local candidate, issue = self:DraftMemberCandidate()
    if not candidate then self.memberIssue = issue; self:Render(); return end
    self.draft = candidate; self.undo.people = nil; self.houseUndo = nil; self.memberEditing = nil; self.memberIsNew = nil; self.removeConfirm = false
    self.openingView = self.memberReturn or "summary"; self:Render()
end

function App:CancelDraftMember()
    self.memberEditing = nil
    self.memberIsNew = nil
    self.memberIssue = ""
    self.removeConfirm = false
    self.openingView = self.memberReturn or "summary"
    self:Render()
end

function App:PrepareNewRun()
    if self.storageBlocked or self.unsaved then self:Notify("请先恢复或保存当前进度，再立新家谱。", "warning"); return end
    if self.openingGenerationFailed then
        -- 仅首次自动生成失败的封面可明确重试，不能把任意未开局草案当作可重掷对象。
        local candidate, issue = Opening.Generate(self.profile, Opening.FreshSeed(), "mortal")
        if not candidate then
            self.openingFeedback = issue or "暂未生成合法家庭，请重试。"
            self.screen = "cover"; self:Render()
            return
        end
        self.draft = candidate; self.openingGenerationFailed = false
    elseif self.run and not self.previousDraft then
        local candidate, issue = Opening.Generate(self.profile, Opening.FreshSeed(), "mortal")
        if not candidate then self.openingFeedback = issue; self:Notify(issue, "error"); return end
        self.previousDraft = self.draft; self.draft = candidate
    end
    self.editBackup = nil; self.houseUndo = nil; self.undo = {}
    self.screen = "opening"; self.openingView = "summary"; self.openingFeedback = ""; self:Render()
end

function App:CancelNewRun()
    if not self.previousDraft then return end
    self.draft = self.previousDraft; self.previousDraft = nil; self.undo = {}; self.editBackup = nil; self.houseUndo = nil
    self.screen = "game"; self:Render()
end

function App:StartRun()
    if self.storageBlocked or self.unsaved then self:Notify("请先恢复或保存当前进度，再立新家谱。", "warning"); return end
    if self.startConfirmationOpen or self.screen == "game" then return end
    local issues = State.ValidateDraft(self.draft, self.profile, false)
    if #issues > 0 then
        self.openingFeedback = table.concat(issues, "\n")
        self:Render(); self:Notify("请先修正开局草案。", "error"); return
    end
    local previousRun, submitted = self.run, false
    local function commit()
        if submitted or self.run ~= previousRun then return end
        submitted = true
        local candidate, errors = State.NewRun(self.draft, self.profile)
        if not candidate then self:Notify(table.concat(errors, " "), "error"); return end
        -- 先验证写入，再切换当前局；失败时旧 run、收藏和正在展示的草案都在。
        local ok, message = State.Save(self.profile, self.draft, candidate)
        if not ok then
            self.saveMessage = "新局未开始。" .. message
            self:Render(); self:Notify(self.saveMessage, "error"); return
        end
        self.run = candidate; self.previousDraft = nil; self.saveMessage = ""
        self.screen = "game"; self.gameTab = "family"; self.historyPage = 1; self.undo = {}
        self:Render(); self:Notify("家谱开篇。已保留收藏，并保存当前家谱。", "success")
    end
    if not self.run then commit(); return end
    self.startConfirmationOpen = true
    local modal = UI.Modal { title = "开始新家谱？", size = "sm",
        backgroundColor = C.card, borderColor = C.line, titleTextColor = C.ink, closeIconColor = C.muted,
        onClose = function(selfModal)
        self.startConfirmationOpen = false; selfModal:Destroy()
    end }
    modal:AddContent(Label("当前家谱将由眼前这份新草案替换。已解锁收藏与终章档案保留；如需长期留存旧局，请先导出。", { whiteSpace = "normal", fontSize = 16 }))
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("取消", function() modal:Close() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        Button("确认开始", function() modal:Close(); commit() end, { flex = 1 }),
    } })
    modal:Open()
end

function App:RunAction(fn)
    if self.unsaved then self:Notify("上一项安排尚未保存，请重试保存；无需重复安排。", "warning"); return end
    if self.actionBusy then
        self:Notify("上一项安排正在写入，请勿重复操作。", "warning")
        return
    end
    self.actionBusy = true
    local ok, message = fn()
    self.actionBusy = false
    if ok then
        if self:Save() then self:Notify(message, "success") end
    else self:Notify(message, "warning") end
end

function App:BuildHeader(title, subtitle)
    return UI.Panel {
        height = 54, flexDirection = "row", alignItems = "center", justifyContent = "space-between", paddingHorizontal = 12,
        backgroundColor = C.paper, borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            UI.Panel { flexDirection = "column", pointerEvents = "none", children = { Label(title, { fontSize = 22, fontWeight = "bold", fontColor = C.green }), Label(subtitle, { fontSize = 10, fontColor = C.muted }) } },
            Button(self.unsaved and "重试保存" or "存档", function() self:Save() end, { width = self.unsaved and 76 or 56, height = 32, fontSize = 11, backgroundColor = C.pale, textColor = C.green }),
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

function App:BuildFinalPage()
    return OpeningView.Summary(self)
end

function App:BuildCover()
    local actions = {
        Label("家业", { fontSize = 42, fontWeight = "bold", fontColor = { 255, 254, 250, 255 } }),
        Label("一部由选择写成的家谱", { fontSize = 18, fontColor = { 226, 235, 220, 255 } }),
        Label("立一户人家，过一年算一年。有人出生、有人离去，手艺、声望与旧物都会留在家史里。", { fontSize = 15, fontColor = { 226, 235, 220, 255 }, whiteSpace = "normal", lineHeight = 1.65, marginTop = 12 }),
    }
    if self.openingGenerationFailed then
        table.insert(actions, Label(self.openingFeedback, { fontSize = 14, fontColor = { 255, 207, 184, 255 }, whiteSpace = "normal", lineHeight = 1.5 }))
    end
    table.insert(actions, Button("立一部家谱", function() self:PrepareNewRun() end, { height = 52, fontSize = 17, marginTop = 20 }))
    table.insert(actions, Button("读取最近存档", function() self:Load() end, { height = 46, backgroundColor = C.pale, textColor = C.green }))
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.dark, justifyContent = "center", padding = 26, children = {
        UI.Panel { gap = 16, children = actions },
    } }
end

function App:BuildOpening()
    return OpeningView.Build(self)
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

function App:BuildFamilyRoutes()
    local active = { peaceful = true, grain = self.run.land > 0, community = self.run.reputation > 0 }
    for _, member in ipairs(self.run.members) do
        local jobId = member.jobId
        if jobId == "study" or jobId == "teach" or jobId == "official" then active.scholar = true end
        if jobId == "trade" then active.merchant = true end
        if jobId == "apprentice" or jobId == "craft" then active.craft = true end
        if jobId == "medical" or jobId == "doctor" then active.medical = true end
        if jobId == "farm" then active.grain = true end
        if jobId == "guard" or member.hadHomeAfterGuard then active["return"] = true end
    end
    if self.run.workshop then active.craft = true end
    if self.run.shop then active.merchant = true end
    if (self.run.metrics["migrations"] or 0) > 0 then active.migration = true end
    if (self.run.metrics["aid"] or 0) > 0 then active.community = true end
    for _, relic in ipairs(self.run.relicInstances) do
        if relic.status ~= "sold" then
            if relic.definitionId == "letter" or relic.definitionId == "jade" then active.promise = true end
            if relic.definitionId == "ruler" or relic.definitionId == "plan" then active.ruler = true end
            if relic.definitionId == "book" or relic.definitionId == "newbook" then active.reunion = true end
        end
    end

    local routes = {}
    for order, ending in ipairs(Data.Endings) do
        local progress, total, complete, score = Simulation.EndingProgress(self.run, ending["id"]), 0, 0, 0
        for _, item in ipairs(progress) do
            local current, required = math.max(0, item[2]), item[3]
            total = total + 1
            score = score + math.min(current / required, 1)
            if current >= required then complete = complete + 1 end
        end
        local ready = complete == total and total > 0
        table.insert(routes, { ending = ending, progress = progress, complete = complete, total = total, ready = ready, active = active[ending["id"]] == true, score = score, order = order })
    end
    table.sort(routes, function(a, b)
        if a.ready ~= b.ready then return a.ready end
        if a.active ~= b.active then return a.active end
        if a.score ~= b.score then return a.score > b.score end
        return a.order < b.order
    end)

    local cards = {
        Label("正在形成的家业", { fontSize = 17, fontWeight = "bold" }),
        Label("终章只认本局真实经历。这里显示最接近的三条路；达成后由你决定是否以它落笔。", { fontSize = 11, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
    }
    for index = 1, math.min(3, #routes) do
        local route = routes[index] --[[@as table<string, any>]]
        local ending = route["ending"] --[[@as table<string, any>]]
        local guidance = ROUTE_GUIDANCE[ending["id"]] or ROUTE_GUIDANCE.peaceful
        local progressLines, nextLine = {}, nil
        for _, item in ipairs(route.progress) do
            table.insert(progressLines, item[1] .. " " .. tostring(item[2]) .. "/" .. tostring(item[3]))
            if not nextLine and item[2] < item[3] then nextLine = item[1] .. " " .. tostring(item[2]) .. "/" .. tostring(item[3]) end
        end
        local state = route.ready and "可落笔" or (route.active and "正在形成" or "可探索")
        local action = route.ready and Button("以此落笔", function()
            self:RunAction(function() return Simulation.ClaimEnding(self.run, ending["id"], self.profile) end)
        end, { height = 32, fontSize = 11 }) or Button(guidance.button, function()
            self.gameTab = guidance.tab; self:Render()
        end, { height = 32, fontSize = 11, backgroundColor = C.pale, textColor = C.green })
        table.insert(cards, UI.Panel {
            padding = 8, gap = 4, backgroundColor = route.ready and C.pale or C.paper, borderWidth = 1, borderColor = route.ready and C.green or C.line, borderRadius = 8,
            children = {
                UI.Row { justifyContent = "space-between", children = { Label(ending["title"], { fontSize = 14, fontWeight = "bold" }), Label(state, { fontSize = 10, fontColor = route.ready and C.green or C.muted }) } },
                Label(ending["desc"], { fontSize = 11, fontColor = C.muted, whiteSpace = "normal" }),
                Label("进展：" .. table.concat(progressLines, " · "), { fontSize = 10, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.35 }),
                Label(route.ready and "条件已齐。确认后会将此局写成只读家史。" or "下一步：" .. tostring(nextLine) .. "。" .. guidance.hint, { fontSize = 10, whiteSpace = "normal", lineHeight = 1.35, fontColor = C.ink }),
                action,
            },
        })
    end
    return Card(cards, { padding = 10, gap = 7 })
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
        table.insert(children, Card({ Label("本局已落笔", { fontSize = 17, fontWeight = "bold" }), Label(tostring(completedEnding["summary"] or "这段家史已被妥善收录。"), { fontSize = 12, whiteSpace = "normal" }), Button("新立家谱", function() self:PrepareNewRun() end, { height = 36 }) }))
    else
        table.insert(children, self:BuildFamilyRoutes())
    end
    if not self.run.ending and #pending > 0 then
        table.insert(children, Card({ Label("先处理眼前这件事", { fontSize = 16, fontWeight = "bold" }), Label("事件处理后，才能结算下一年。", { fontSize = 11, fontColor = C.muted }) }))
        for _, event in ipairs(pending) do table.insert(children, self:BuildPendingEvent(event)) end
    elseif not self.run.ending then
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
    local modal = UI.Modal { title = member.name .. " · " .. tostring(member.age) .. " 岁", size = "fullscreen",
        backgroundColor = C.card, borderColor = C.line, titleTextColor = C.ink, closeIconColor = C.muted,
        closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end }
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
    local pageSize = 20
    local pageCount = math.max(1, math.ceil(#self.run.logs / pageSize))
    self.historyPage = math.max(1, math.min(self.historyPage, pageCount))
    local function turnTo(page) self.historyPage = page; self:Render() end
    local logCards = {}
    ---@type {year: number, text: string}[]
    local logs = self.run.logs
    for index = (self.historyPage - 1) * pageSize + 1, math.min(self.historyPage * pageSize, #self.run.logs) do
        local log = logs[index]
        table.insert(logCards, Label("大晟历 " .. tostring(log.year) .. " 年 · " .. log.text, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.5 }))
    end
    if #logCards == 0 then table.insert(logCards, Label("家史尚未写下新事。", { fontSize = 13, fontColor = C.muted })) end
    local pager = UI.Row { gap = 5, children = {
        Button("最新", function() turnTo(1) end, { flex = 1, disabled = self.historyPage == 1 }),
        Button("上一页", function() turnTo(self.historyPage - 1) end, { flex = 1, disabled = self.historyPage == 1 }),
        Button("下一页", function() turnTo(self.historyPage + 1) end, { flex = 1, disabled = self.historyPage == pageCount }),
        Button("最早", function() turnTo(pageCount) end, { flex = 1, disabled = self.historyPage == pageCount }),
    } }
    return UI.Panel { gap = 12, children = {
        Card({ Label("家史", { fontSize = 21, fontWeight = "bold" }), Label("家史全量保留，按新到旧分页。", { fontSize = 13, fontColor = C.muted }),
            UI.Row { gap = 8, children = {
                Button("导出本局", function() self:Export() end, { flex = 1 }),
                Button("新立家谱", function() self:PrepareNewRun() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
            } },
        }),
        Card({ Label("年鉴 · " .. tostring(#self.run.logs) .. " 条 · 第 " .. tostring(self.historyPage) .. "/" .. tostring(pageCount) .. " 页", { fontSize = 18, fontWeight = "bold" }), pager, UI.Panel { gap = 8, children = logCards } }),
        Card({ Label("可探索的终章", { fontSize = 18, fontWeight = "bold" }), UI.Panel { gap = 8, children = endingCards } }),
    } }
end

function App:BuildGame()
    local builders = { family = function() return self:BuildFamilyTab() end, people = function() return self:BuildPeopleTab() end, estate = function() return self:BuildEstateTab() end, relics = function() return self:BuildRelicsTab() end, history = function() return self:BuildHistoryTab() end }
    local openingSnapshot = TableValue(self.run.openingSnapshot)
    local children = {
        self:BuildRunStatusBar(),
        self:BuildHeader("家业", tostring(openingSnapshot["family"] or "无名") .. "氏家谱 · " .. Data.Place(self.run.placeId).short),
        UI.ScrollView { flexGrow = 1, flexBasis = 0, padding = 12, children = { builders[self.gameTab]() } },
    }
    local annualFooter = self:BuildAnnualFooter()
    if annualFooter then table.insert(children, annualFooter) end
    table.insert(children, self:BuildGameNav())
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.paper, flexDirection = "column", children = children }
end

function App:Render()
    local page = self.screen == "cover" and self:BuildCover() or (self.screen == "opening" and self:BuildOpening() or self:BuildGame())
    local children = {}
    if self.saveMessage ~= "" then
        table.insert(children, UI.Panel { padding = 8, gap = 6, backgroundColor = C.paper, children = {
            Label(self.saveMessage, { fontSize = 14, fontColor = C.warning, whiteSpace = "normal" }),
            UI.Row { gap = 8, children = {
                Button(self.storageBlocked and "重新读取" or "重试保存", function() if self.storageBlocked then self:Load() else self:Save() end end, { flex = 1 }),
                Button("导出当前进度", function() self:Export() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
            } },
        } })
    end
    table.insert(children, UI.Panel { flexGrow = 1, flexBasis = 0, minHeight = 0, children = { page } })
    local phoneFrame = UI.Panel {
        width = "100%",
        maxWidth = 430,
        height = "100%",
        backgroundColor = C.paper,
        overflow = "hidden",
        flexDirection = "column",
        children = children,
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
