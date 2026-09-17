local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Opening = require "Jiaye.Opening"
local OpeningView = require "Jiaye.OpeningView"

local App = {}
App.__index = App

local C = {
    paper = { 248, 247, 239, 255 }, card = { 255, 254, 248, 255 }, ink = { 35, 66, 53, 255 },
    muted = { 95, 113, 102, 255 }, line = { 207, 216, 196, 255 }, green = { 53, 100, 77, 255 },
    dark = { 38, 75, 58, 255 }, pale = { 228, 237, 215, 255 }, warning = { 174, 83, 59, 255 }, gold = { 157, 134, 96, 255 },
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
    return UI.Label(props)
end

local function Button(text, onClick, props)
    props = props or {}; props.text = text; props.onClick = onClick; props.height = props.height or 44
    props.backgroundColor = props.backgroundColor or C.green; props.textColor = props.textColor or { 255, 255, 255, 255 }
    props.borderRadius = props.borderRadius or 8
    return UI.Button(props)
end

local function Card(children, props)
    props = props or {}; props.backgroundColor = props.backgroundColor or C.card; props.borderColor = props.borderColor or C.line
    props.borderWidth = props.borderWidth or 1; props.borderRadius = props.borderRadius or 10; props.padding = props.padding or 11; props.gap = props.gap or 7
    props.flexDirection = "column"; props.children = children
    return UI.Panel(props)
end

local function LastGlyph(value)
    local glyph = "人"
    for _, codepoint in utf8.codes(value or "") do glyph = utf8.char(codepoint) end
    return glyph
end

local function SectionTitle(title, detail)
    return UI.Row {
        justifyContent = "space-between", alignItems = "center",
        children = {
            UI.Row { gap = 7, alignItems = "center", children = {
                Label("◇", { fontSize = 18, fontColor = C.gold }),
                Label(title, { fontSize = 20, fontWeight = "bold" }),
            } },
            detail and Label(detail, { fontSize = 14, fontColor = C.muted }) or UI.Panel { width = 0 },
        },
    }
end

local function MemberSeal(member, leader)
    return UI.Panel {
        width = 64, height = 64, borderRadius = 32, borderWidth = 2,
        borderColor = leader and C.green or C.gold,
        backgroundColor = leader and C.pale or { 247, 243, 230, 255 },
        justifyContent = "center", alignItems = "center",
        children = { Label(LastGlyph(member.name), { fontSize = 28, fontColor = leader and C.green or C.gold }) },
    }
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

local function MemberNames(run, memberIds)
    local names = {}
    for _, memberId in ipairs(memberIds or {}) do
        local member = State.FindMember(run.members, memberId)
        if member then table.insert(names, member.name) end
    end
    return #names > 0 and table.concat(names, "、") or "未关联族人"
end

local function MemberRelationText(run, member)
    local relations = {}
    if member.id == run.leaderId then table.insert(relations, "现任族长") end
    local parentNames = MemberNames(run, member.parents)
    if parentNames ~= "未关联族人" then table.insert(relations, "亲长：" .. parentNames) end
    local spouse = member.spouseId and State.FindMember(run.members, member.spouseId)
    if spouse then table.insert(relations, "配偶：" .. spouse.name) end
    for _, candidate in ipairs(run.members) do
        for _, parentId in ipairs(candidate.parents or {}) do
            if parentId == member.id then table.insert(relations, "子女：" .. candidate.name) end
        end
    end
    return #relations > 0 and table.concat(relations, " · ") or "家谱关系待续"
end

local function EventSourceText(event)
    local sources = {
        relic_resolution = "信物调查", medical_find = "医馆托付", plan_work = "营造图线索", jade_search = "玉佩查访",
        school = "族中孩子", community_request = "乡里来信", roof = "家宅日常", notes_choice = "批注医案",
        growth = "人生节点", leader = "族长任期",
    }
    return sources[event.type] or "家中事务"
end

local function ProgressText(item)
    local mark = item[6] == "at_most" and "≤" or "/"
    return item[1] .. "（" .. tostring(item[4] or "当前") .. "） " .. tostring(item[2]) .. mark .. tostring(item[3])
end

local function EndingEvidenceText(run, item)
    local source = TableValue(item.source)
    local factIds = source.factIds or {}
    local members = {}
    for _, memberId in ipairs(source.memberIds or {}) do
        local member = State.FindMember(run.members, memberId)
        if member then table.insert(members, member.name) end
    end
    local references = #factIds > 0 and tostring(#factIds) .. " 条记录" or ""
    if #members > 0 then references = references .. (#references > 0 and "、" or "") .. table.concat(members, "、") end
    local suffix = #references > 0 and " · 依据：" .. references or ""
    local mark = (item.comparison or item[6]) == "at_most" and "≤" or "/"
    local label = item.label or item[1] or "终章条件"
    local measure = item.measure or item[4] or "快照"
    local current = item.current or item[2] or 0
    local required = item.required or item[3] or 0
    return tostring(label) .. "（" .. tostring(measure) .. "） " .. tostring(current) .. mark .. tostring(required) .. " · " .. tostring(source.source or "本局记录") .. suffix
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
    self.peopleQueryDraft = ""
    self.historySection = "annals"
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
    self.previousDraft = nil; self.editBackup = nil; self.houseUndo = nil; self.openingView = "summary"; self.undo = {}; self.historyPage = 1; self.peopleQuery = ""; self.peopleQueryDraft = ""; self.historySection = "annals"; self.storageBlocked = false; self.openingGenerationFailed = false
    self.saveMessage = status == "recovered" and message or ""
    self.screen = self.run and "game" or "opening"
    self:Render(); self:Notify(message, status == "recovered" and "warning" or "success")
end

function App:Export()
    local raw, message = State.Export(self.profile, self.previousDraft or self.draft, self.run)
    self:Notify(message, raw and "success" or "error")
end

function App:OpenImport()
    if self.unsaved then self:Notify("当前安排尚未保存，请先重试保存或导出，避免覆盖内存中的进度。", "warning"); return end
    self.importRaw = ""
    local modal = UI.Modal { title = "导入家业备份", size = "fullscreen", closeOnOverlay = true }
    modal:AddContent(Label("粘贴由《家业》导出的完整 JSON。系统会先隔离解析、校验版本、结构和所有人物/物件引用；确认前不会改动当前进度。", { fontSize = 15, whiteSpace = "normal", lineHeight = 1.55 }))
    modal:AddContent(UI.TextField {
        value = "", placeholder = "粘贴 JSON 备份内容", maxLength = 15000000,
        onChange = function(_, value) self.importRaw = value end,
    })
    modal:SetFooter(UI.Panel { flexDirection = "column", gap = 8, children = {
        Button("校验并预演", function()
            local candidate, message, status = State.PreflightImport(self.importRaw)
            if not candidate then self:Notify(message, "error"); return end
            modal:Close(); self:ConfirmImport(candidate, message, status)
        end, { height = 48 }),
        Button("取消", function() modal:Close() end, { height = 44, backgroundColor = C.pale, textColor = C.green }),
    } })
    modal:Open()
end

function App:ConfirmImport(candidate, previewMessage, status)
    local modal = UI.Modal { title = "确认替换当前进度", size = "lg", closeOnOverlay = false }
    modal:AddContent(Label(previewMessage, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.55 }))
    modal:AddContent(Label("确认后写入新的可回读存档；当前进度在写入失败时保持原样。重复确认同一份备份只保留一份结果。", { fontSize = 14, whiteSpace = "normal", lineHeight = 1.5, fontColor = C.muted }))
    modal:SetFooter(UI.Panel { flexDirection = "column", gap = 8, children = {
        Button("确认导入", function()
            local ok, message, result = State.CommitImport(candidate)
            if not ok then self:Notify(message, "error"); return end
            local loaded, loadMessage = State.Load()
            if not loaded then self:Notify("导入写入后无法读取，请保留备份并重试。", "error"); return end
            self.profile, self.draft, self.run = loaded.profile, loaded.draft, loaded.run
            self.previousDraft = nil; self.editBackup = nil; self.houseUndo = nil; self.undo = {}; self.historyPage = 1
            self.peopleQuery = ""; self.peopleQueryDraft = ""; self.historySection = "annals"; self.storageBlocked = false
            self.unsaved = false; self.saveMessage = ""; self.openingGenerationFailed = false
            self.screen = self.run and "game" or "opening"
            modal:Close(); self:Render(); self:Notify(result == "duplicate" and message or (message .. " " .. loadMessage), "success")
        end, { height = 48 }),
        Button("保留当前进度", function() modal:Close() end, { height = 44, backgroundColor = C.pale, textColor = C.green }),
    } })
    modal:Open()
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
    self.memberSection = "base"; self.memberIssue = ""; self.removeConfirm = false; self.memberRemoving = false
    self.openingView = "member"; self:Render()
end

function App:MarkDraftMemberForRemoval()
    if self.memberIsNew or not self.memberEditing then return end
    if #self.draft.members <= 1 then self.memberIssue = "至少保留一位族人。"; self:Render(); return end
    self.memberRemoving = true
    self.memberIssue = ""
    self:Render()
end

function App:OpenDraftMember(memberId)
    local member = State.FindMember(self.draft.members, memberId)
    if not member then return end
    self.memberEditing = State.Copy(member); self.memberIsNew = false; self.memberLeader = self.draft.leaderId
    self.memberReturn = self.openingView; self.memberSection = "base"; self.memberIssue = ""; self.removeConfirm = false; self.memberRemoving = false
    self.openingView = "member"; self:Render()
end

-- 预览和保存共用同一份候选草案；新成员尚未写入 draft 时也按最终形态计分和校验。
function App:DraftMemberCandidate()
    local candidate, issue
    if self.memberRemoving then
        candidate = State.Copy(self.draft)
        local removed = self.memberEditing and self.memberEditing.id
        if not removed then return nil, "没有可移除的成员，草案未改变。" end
        local found = false
        for index, member in ipairs(candidate.members) do
            if member.id == removed then table.remove(candidate.members, index); found = true; break end
        end
        if not found then return nil, "找不到要移除的成员，草案未改变。" end
        for _, member in ipairs(candidate.members) do
            if member.spouseId == removed then member.spouseId = nil end
            local parents = {}
            for _, parentId in ipairs(member.parents) do if parentId ~= removed then table.insert(parents, parentId) end end
            member.parents = parents
        end
        local issues = State.ValidateDraft(candidate, self.profile, true)
        if #issues > 0 then return nil, table.concat(issues, "\n") end
    elseif self.memberIsNew then
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
    local removed = self.memberRemoving
    self.draft = candidate; self.undo.people = nil; self.houseUndo = nil; self.memberEditing = nil; self.memberIsNew = nil; self.memberRemoving = nil; self.removeConfirm = false
    self.openingView = self.memberReturn or "summary"
    self.openingFeedback = removed and "已移除成员并清理关系引用。" or ""
    self:Render()
end

function App:CancelDraftMember()
    self.memberEditing = nil
    self.memberIsNew = nil
    self.memberRemoving = nil
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
    if self.run and self.run.ending then self:Notify("本局已落笔，只能回顾家史。", "warning"); return end
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

function App:ConfirmRunAction(title, detail, action, confirmText, parentModal)
    if self.run and self.run.ending then self:Notify("本局已落笔，只能回顾家史。", "warning"); return end
    local modal = UI.Modal { title = title, size = "fullscreen", backgroundColor = C.card, borderColor = C.line,
        titleTextColor = C.ink, closeIconColor = C.muted, closeOnOverlay = true,
        onClose = function(selfModal) selfModal:Destroy() end }
    modal:AddContent(UI.Panel { padding = 14, gap = 9, children = {
        Label(detail, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.55 }),
        Label("确认后会立刻写入本局家谱、账本与年鉴。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
    } })
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("返回", function() modal:Close() end, { flex = 1, height = 46, backgroundColor = C.pale, textColor = C.green }),
        Button(confirmText or "确认执行", function()
            self:RunAction(action)
            modal:Close()
            if parentModal then parentModal:Close() end
        end, { flex = 1, height = 46 }),
    } })
    modal:Open()
end

function App:ConfirmEventChoice(event, label, detail, choice)
    local participant = event.executorId and State.FindMember(self.run.members, event.executorId) or State.FindMember(self.run.members, event.memberId)
    local modal = UI.Modal { title = "家族事件", size = "fullscreen", backgroundColor = C.card, borderColor = C.line,
        titleTextColor = C.ink, closeIconColor = C.muted, closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end }
    modal:AddContent(UI.Panel { padding = 14, gap = 13, children = {
        Label("家 族 事 件", { fontSize = 13, fontColor = C.muted, textAlign = "center" }),
        Label(event.title, { fontSize = 29, fontWeight = "bold", textAlign = "center", whiteSpace = "normal", lineHeight = 1.25 }),
        Card({
            UI.Row { gap = 11, alignItems = "center", children = {
                UI.Panel { width = 56, height = 56, justifyContent = "center", alignItems = "center", backgroundColor = {244,239,222,255}, borderWidth = 2, borderColor = C.gold, children = { Label("事", { fontSize = 27, fontColor = C.gold }) } },
                UI.Panel { flex = 1, minWidth = 0, children = {
                    Label("来源 · " .. EventSourceText(event), { fontSize = 14, fontColor = C.muted }),
                    Label("参与人 · " .. (participant and participant.name or "全家"), { fontSize = 16, fontWeight = "bold" }),
                } },
            } },
        }),
        Label(event.desc or "这件家事会随你的决定写入本局的年鉴与参与人的人生。", { fontSize = 16, whiteSpace = "normal", lineHeight = 1.6 }),
        Card({
            Label("你准备这样决定", { fontSize = 13, fontColor = C.muted }),
            Label(label, { fontSize = 21, fontWeight = "bold" }),
            Label(detail, { fontSize = 15, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.55 }),
        }, { backgroundColor = C.pale, borderColor = {151,171,118,255} }),
        Label("确认前不会扣除费用，也不会改变任何安排。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
    } })
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("返回", function() modal:Close() end, { flex = 1, height = 48, backgroundColor = C.pale, textColor = C.green }),
        Button("确认这个决定", function()
            self:RunAction(function() return Simulation.ResolveEvent(self.run, event.instanceId, choice, self.profile) end)
            modal:Close()
        end, { flex = 1, height = 48 }),
    } })
    modal:Open()
end

function App:ConfirmEnding(endingId)
    local ending = Data.Ending(endingId)
    if not ending or ending.automatic then self:Notify("这条终章不能由家主确认。", "warning"); return end
    if not Simulation.IsEndingReady(self.run, endingId) then self:Notify("条件尚未满足。", "warning"); return end
    local conditionLines = {}
    for _, item in ipairs(Simulation.EndingProgress(self.run, endingId)) do
        table.insert(conditionLines, Label(ProgressText(item), { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }))
    end
    local modal = UI.Modal { title = "确认落笔 · " .. ending.title, size = "fullscreen", backgroundColor = C.card, borderColor = C.line, titleTextColor = C.ink, closeIconColor = C.muted, closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end }
    modal:AddContent(UI.Panel { padding = 14, gap = 9, children = {
        Label(ending.desc, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.45 }),
        Label("以下本局经历会作为终章条件快照写入家史。确认后，人物、家业、事件和信物将进入只读状态。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
        UI.Panel { gap = 5, children = conditionLines },
    } })
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("继续经营", function() modal:Close() end, { flex = 1, height = 40, backgroundColor = C.pale, textColor = C.green }),
        Button("确认落笔", function()
            self:RunAction(function() return Simulation.ClaimEnding(self.run, endingId, self.profile) end)
            modal:Close()
        end, { flex = 1, height = 40 }),
    } })
    modal:Open()
end

function App:BuildHeader(title, subtitle)
    return UI.Panel {
        height = 54, flexDirection = "row", alignItems = "center", justifyContent = "space-between", paddingHorizontal = 14,
        backgroundColor = C.paper, borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            UI.Panel { flexDirection = "column", pointerEvents = "none", children = { Label(title, { fontSize = 15, fontWeight = "bold", fontColor = C.ink }), Label(subtitle, { fontSize = 12, fontColor = C.muted }) } },
            Button(self.unsaved and "重试保存" or "存档", function() self:Save() end, { width = self.unsaved and 84 or 58, height = 38, fontSize = 12, backgroundColor = C.pale, textColor = C.green }),
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
    local collapseRisk = Simulation.IsFamilyCollapsed(self.run)
    local function metric(name, value, color)
        return UI.Panel {
            height = 76, padding = 7, justifyContent = "center", alignItems = "center",
            backgroundColor = C.card, borderWidth = 1, borderColor = color or C.line,
            children = {
                Label(name, { fontSize = 12, fontColor = C.muted }),
                Label(value, { fontSize = 23, fontWeight = "bold", fontColor = color or C.ink }),
            },
        }
    end
    return UI.Panel {
        paddingHorizontal = 12, paddingVertical = 10, gap = 6, backgroundColor = C.paper,
        children = {
            UI.SimpleGrid { columns = 4, gap = 0, children = {
                metric("公库", tostring(self.run.money) .. " 两", collapseRisk and C.warning or nil),
                metric("存粮", tostring(self.run.grain) .. "/" .. tostring(foodNeed) .. " 石", (foodUnsafe or collapseRisk) and C.warning or nil),
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
    table.insert(actions, Button("导入备份", function() self:OpenImport() end, { height = 44, backgroundColor = C.pale, textColor = C.green }))
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.dark, justifyContent = "center", padding = 26, children = {
        UI.Panel { gap = 16, children = actions },
    } }
end

function App:BuildOpening()
    return OpeningView.Build(self)
end

function App:BuildGameNav()
    local tabs = { { id = "family", text = "⌂\n家族" }, { id = "people", text = "人\n族人" }, { id = "estate", text = "田\n家业" }, { id = "relics", text = "匣\n藏阁" }, { id = "history", text = "册\n家史" } }
    local children = {}
    for _, tab in ipairs(tabs) do table.insert(children, Button(tab.text, function() self.gameTab = tab.id; self:Render() end, { flex = 1, height = 58, fontSize = 12, backgroundColor = self.gameTab == tab.id and C.pale or C.card, textColor = self.gameTab == tab.id and C.green or C.muted, borderRadius = 7 })) end
    return UI.Panel { padding = 5, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = { UI.Row { gap = 3, children = children } } }
end

function App:BuildPendingEvent(event)
    if event.type == "legacy_pending" then
        return Card({
            Label(event.title or "旧版待决家事", { fontSize = 19, fontWeight = "bold" }),
            Label("这条家事由 V5 存档迁入。原始内容已保存在迁移记录中；确认后会写入现有家史，不会重复结算旧版费用或奖励。", { fontSize = 14, whiteSpace = "normal", lineHeight = 1.55 }),
            Button("确认并写入家史", function() self:ConfirmEventChoice(event, "确认迁入旧版家事", "处理结果：原始内容保留，当前家谱只追加一条迁移事实。", "acknowledge") end, { height = 44 }),
        }, { borderColor = C.green })
    end
    if event.type == "relic_resolution" then
        local instance = nil; for _, item in ipairs(self.run.relicInstances) do if item.instanceId == event.relicInstanceId then instance = item end end
        local relic = instance and Data.Relic(instance.definitionId)
        local executor = instance and State.FindMember(self.run.members, event.executorId or instance.executorId)
        local restore = Button(relic and relic.story.restore or "修复并落笔", function()
            self:ConfirmEventChoice(event, relic and relic.story.restore or "修复并落笔", "处理结果：完成修复，当前物件状态、解锁资格与家史会同步更新。", "restore")
        end, { flex = 1 })
        local defer = Button(relic and relic.story.defer or "暂存线索", function()
            self:ConfirmEventChoice(event, relic and relic.story.defer or "暂存线索", "处理结果：保留这条线索，暂不继续修复。", "defer")
        end, { flex = 1, backgroundColor = C.pale, textColor = C.green })
        local actions = UI.Row { gap = 8, children = { restore, defer } }
        return Card({
            Label(event.title, { fontSize = 19, fontWeight = "bold" }),
            Label("“" .. (relic and relic.name or "旧物") .. "”的调查到期。执行人：" .. (executor and executor.name or "待重新指定") .. "。选择会写入家史；解锁奖励只登记一次。", { fontSize = 14, whiteSpace = "normal", lineHeight = 1.6 }),
            actions,
        }, { borderColor = C.green })
    end
    if event.type == "leader" then
        local choices = {}; for _, member in ipairs(self.run.members) do if member.alive and member.age >= 18 then table.insert(choices, Button("任命 " .. member.name, function() self:ConfirmRunAction("确认继任 · " .. member.name, "参与人：" .. member.name .. "\n处理结果：开始新的族长任期，其他族人的主业保持原样。", function() return Simulation.ResolveLeaderEvent(self.run, event.instanceId, member.id) end, "确认任命") end, { height = 44 })) end end
        return Card({ Label("族长之位空缺", { fontSize = 19, fontWeight = "bold" }), Label("家族仍可继续，但需要从在世成年族人中选任族长。", { fontSize = 14, whiteSpace = "normal" }), UI.Panel { gap = 6, children = choices } }, { borderColor = C.warning })
    end
    if event.type == "growth" then
        local member = State.FindMember(self.run.members, event.memberId)
        local job = event.jobId and Data.Jobs[event.jobId] or nil
        local detail = member and (event.growthId == "promotion" and (member.name .. "已具备“" .. (job and job.name or "新岗位") .. "”资格。是否现在查看安排？岗位不会自动改变。") or (member.name .. "已经成年，可以由你决定接下来的安排。")) or "这条成长记录的族人已不在当前家谱中。"
        return Card({
            Label(event.title, { fontSize = 19, fontWeight = "bold" }), Label(detail, { fontSize = 14, whiteSpace = "normal", lineHeight = 1.55 }),
            UI.Row { gap = 8, children = {
                Button("查看安排", function()
                    self:ConfirmEventChoice(event, "确认查看安排", "处理结果：成长节点写入家史，岗位仍需单独确认。", "acknowledge")
                end, { flex = 1 }),
                Button("暂不转业", function() self:ConfirmEventChoice(event, "确认暂缓", "处理结果：本年保持现有安排，暂缓记录会写入经历。", "defer") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
            } },
        }, { borderColor = C.green })
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
            Button("收下医案", function() self:ConfirmEventChoice(event, "收下医案", "结果：批注医案进入本局藏阁，并解锁下一局的开局资格。", "accept") end, { flex = 1 }),
            Button("暂不收下", function() self:ConfirmEventChoice(event, "确认暂留", "结果：医案留在医馆，本次机会会记入家史。", "decline") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "plan_work" then
        actions = UI.Row { gap = 8, children = {
            Button("接下修缮", function() self:ConfirmEventChoice(event, "接下修缮", "条件：公库留有 10 两工料。结果：净得 18 两，声望 +5。", "accept") end, { flex = 1 }),
            Button("婉拒", function() self:ConfirmEventChoice(event, "确认婉拒", "结果：本次修缮活结束，营造图保留在藏阁。", "decline") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "jade_search" then
        actions = UI.Row { gap = 8, children = {
            Button("查访（8 两）", function() self:ConfirmEventChoice(event, "确认查访", "成本：8 两路费。结果：寻回另一半玉佩，声望 +8。", "search") end, { flex = 1 }),
            Button("暂存", function() self:ConfirmEventChoice(event, "确认暂存", "结果：玉佩线索保存，暂不支付路费。", "defer") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "school" then
        actions = UI.Row { gap = 8, children = {
            Button("添书（6 两）", function() self:ConfirmEventChoice(event, "确认添书", "成本：6 两。结果：全部在世未成年族人学识 +4。", "support") end, { flex = 1 }),
            Button("暂缓", function() self:ConfirmEventChoice(event, "确认暂缓", "结果：本年保留书本钱，事件会写入年鉴。", "decline") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "community_request" then
        actions = UI.Row { gap = 8, children = {
            Button("接济（15 两）", function() self:ConfirmEventChoice(event, "确认接济", "成本：15 两。结果：接济次数与声望会写入本局记录。", "aid") end, { flex = 1 }),
            Button("婉拒", function() self:ConfirmEventChoice(event, "确认婉拒", "结果：本次周转请求结束，家史保留决定。", "decline") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "roof" then
        actions = UI.Row { gap = 8, children = {
            Button("修补（8 两）", function() self:ConfirmEventChoice(event, "确认修补", "成本：8 两。结果：屋顶修好，声望 +2。", "repair") end, { flex = 1 }),
            Button("暂缓", function() self:ConfirmEventChoice(event, "确认暂缓", "结果：屋顶留待以后处理，年鉴会记录这次决定。", "decline") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        } }
    elseif event.type == "notes_choice" then
        actions = UI.Row { gap = 8, children = {
            Button("刊印（8 两）", function() self:ConfirmEventChoice(event, "确认刊印", "成本：8 两。结果：医案刊印，声望 +8。", "print") end, { flex = 1 }),
            Button("传给后人", function() self:ConfirmEventChoice(event, "确认传承", "结果：医案改为传承状态，保留给后人。", "pass") end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
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
        if not ending.automatic then
            local progress, total, complete, score = Simulation.EndingProgress(self.run, ending["id"]), 0, 0, 0
            for _, item in ipairs(progress) do
                local current, required = math.max(0, item[2]), item[3]
                total = total + 1
                score = score + math.min(current / required, 1)
                if Simulation.IsProgressMet(item) then complete = complete + 1 end
            end
            local ready = complete == total and total > 0
            table.insert(routes, { ending = ending, progress = progress, complete = complete, total = total, ready = ready, active = active[ending["id"]] == true, score = score, order = order })
        end
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
            local text = ProgressText(item)
            table.insert(progressLines, text)
            if not nextLine and not Simulation.IsProgressMet(item) then nextLine = text end
        end
        local state = route.ready and "可落笔" or (route.active and "正在形成" or "可探索")
        local action = route.ready and Button("以此落笔", function()
            self:ConfirmEnding(ending["id"])
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

function App:BuildFamilyMap()
    local generations, order = {}, {}
    for _, member in ipairs(self.run.members) do
        local generation = State.Generation(self.run.members, member.id)
        if not generations[generation] then generations[generation] = {}; table.insert(order, generation) end
        table.insert(generations[generation], member)
    end
    table.sort(order)
    local children = {
        UI.Row { justifyContent = "space-between", alignItems = "center", children = {
            SectionTitle("家谱", nil),
            Button("全体与筛选  ›", function() self.gameTab = "people"; self:Render() end, { height = 40, fontSize = 12, backgroundColor = C.pale, textColor = C.green }),
        } },
        Label("每个人都可以查看人生与安排；已故族人仍保留在家史中。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
    }
    for _, generation in ipairs(order) do
        local nodes = {}
        for _, member in ipairs(generations[generation]) do
            local leader = member.id == self.run.leaderId
            local state = leader and "族长" or (member.alive and "在世" or "已故")
            table.insert(nodes, Card({
                UI.Panel { alignItems = "center", children = { MemberSeal(member, leader) } },
                Label(member.name, { fontSize = 18, fontWeight = "bold", fontColor = member.alive and C.ink or C.muted, textAlign = "center" }),
                Label(tostring(member.age) .. " 岁 · " .. (member.alive and Data.Jobs[member.jobId].name or "生平封存"), { fontSize = 13, fontColor = C.muted, textAlign = "center", whiteSpace = "normal" }),
                Label(state, { fontSize = 12, fontColor = leader and C.warning or (member.alive and C.green or C.muted), textAlign = "center" }),
                Button(member.alive and "查看与安排" or "阅读生平", function() self:OpenRunMember(member.id) end, { height = 40, fontSize = 12, backgroundColor = leader and C.green or C.pale, textColor = leader and { 255, 255, 255, 255 } or C.green }),
            }, { padding = 10, gap = 6, backgroundColor = leader and { 238, 244, 231, 255 } or C.card, borderColor = leader and { 151, 171, 118, 255 } or C.line }))
        end
        table.insert(children, Label("第 " .. tostring(generation) .. " 代 · " .. tostring(#generations[generation]) .. " 人", { fontSize = 14, fontWeight = "bold", marginTop = 4, fontColor = C.muted }))
        table.insert(children, UI.SimpleGrid { minColumnWidth = 155, gap = 10, children = nodes })
    end
    return Card(children, { padding = 11, gap = 9 })
end

function App:BuildFamilyTab()
    local leader = State.FindMember(self.run.members, self.run.leaderId)
    local _, foodNeed = self:GetRunOverview()
    local pending = Simulation.PendingEvents(self.run)
    local completedEnding = TableValue(self.run.ending)
    local children = {}
    if self.run.ending then
        local evidenceLines = {}
        for _, item in ipairs(completedEnding.evidence or {}) do table.insert(evidenceLines, Label(EndingEvidenceText(self.run, item), { fontSize = 11, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 })) end
        table.insert(children, Card({
            Label("本局已落笔 · " .. tostring(completedEnding.title or "家谱落笔"), { fontSize = 17, fontWeight = "bold" }),
            Label(completedEnding.automatic and (Data.Ending(completedEnding.id).automaticHint or "自然终局已自动写入家史。") or "主终章已由家主确认，家史现为只读。", { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
            Label(tostring(completedEnding["summary"] or "这段家史已被妥善收录。"), { fontSize = 12, whiteSpace = "normal" }),
            UI.Panel { gap = 4, children = evidenceLines },
            Button("新立家谱", function() self:PrepareNewRun() end, { height = 36 }),
        }))
    elseif #pending > 0 then
        table.insert(children, Card({
            Label("有件家事，等你决定", { fontSize = 14, fontColor = C.warning }),
            Label("先处理眼前家事，再继续这一年。", { fontSize = 21, fontWeight = "bold" }),
        }, { backgroundColor = C.pale, borderColor = { 151, 171, 118, 255 }, gap = 4 }))
        for _, event in ipairs(pending) do table.insert(children, self:BuildPendingEvent(event)) end
    else
        local firstYear = self.run.yearIndex == 0
        local guidance = Simulation.IsFamilyCollapsed(self.run) and "公库与存粮同时为零。若推进本年结算后仍同时归零，家谱会以“家道散尽”落笔；先安排能带回钱粮的主业。" or (firstYear and "先看每位族人的主业；如果手艺人或经商者没有产业，再到“家业”页置办。确认后，点底部“推进这一年”。" or (self.run.grain < foodNeed and "粮食不足以覆盖这一年：先在“族人”页安排耕作，或到“家业”页购粮、置办田地。" or "本年已有安排。你可以微调族人主业、置办家业，或直接推进年度结算。"))
        table.insert(children, Card({
            Label(firstYear and "第一年这样开始" or "这一年的优先事项", { fontSize = 14, fontColor = C.muted }),
            Label(firstYear and "先把这一家安顿好" or "这一年的日子，由你来决定", { fontSize = 21, fontWeight = "bold" }),
            Label(guidance, { fontSize = 12, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
            UI.Row { gap = 7, children = {
                Button("安排族人", function() self.gameTab = "people"; self:Render() end, { flex = 1, height = 44, backgroundColor = C.pale, textColor = C.green, fontSize = 13 }),
                Button("查看家业", function() self.gameTab = "estate"; self:Render() end, { flex = 1, height = 44, backgroundColor = C.pale, textColor = C.green, fontSize = 13 }),
            } },
        }))
    end
    table.insert(children, self:BuildFamilyMap())
    return UI.Panel { gap = 12, children = children }
end

function App:OpenRunMember(memberId)
    local member = State.FindMember(self.run.members, memberId); if not member then return end
    local modal = UI.Modal { title = "一个人的一生", size = "fullscreen",
        backgroundColor = C.card, borderColor = C.line, titleTextColor = C.ink, closeIconColor = C.muted,
        closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end }
    local body = UI.Panel { gap = 9, children = {} }
    local content = UI.ScrollView { height = "70%", flexBasis = 0, padding = 14, children = { body } }
    local talent = Data.Talent(math.tointeger(member.talent) or 1)
    local experience = Data.Experience(member.experienceId)
    local stats = {
        { "学识", member.stats.learn }, { "手艺", member.stats.skill }, { "医术", member.stats.medicine },
        { "经营", member.stats.trade }, { "武艺", member.stats.martial }, { "体魄", member.health },
    }
    local section = "overview"
    local renderSection
    local function tabs()
        local labels = { { id = "overview", text = "概况" }, { id = "arrangement", text = "安排" }, { id = "life", text = "经历" } }
        local children = {}
        for _, item in ipairs(labels) do
            table.insert(children, Button(item.text, function() section = item.id; renderSection() end, {
                flex = 1, height = 42, fontSize = 15,
                backgroundColor = section == item.id and C.green or C.paper,
                textColor = section == item.id and { 255, 255, 255, 255 } or C.green,
                borderRadius = 0,
            }))
        end
        return UI.Row { gap = 0, children = children }
    end
    local function overview()
        body:AddChild(tabs())
        body:AddChild(UI.Panel { flexDirection = "row", gap = 14, alignItems = "center", children = {
            MemberSeal(member, member.id == self.run.leaderId),
            UI.Panel { flex = 1, minWidth = 0, children = {
                Label(member.name, { fontSize = 29, fontWeight = "bold" }),
                Label(member.sex .. " · " .. tostring(member.age) .. " 岁 · 第 " .. tostring(State.Generation(self.run.members, member.id)) .. " 代", { fontSize = 15, fontColor = C.muted }),
                UI.Label { text = talent.name .. "资质 " .. tostring(member.talent) .. "/5", fontSize = 13, fontColor = C.ink, backgroundColor = C.pale, borderColor = C.line, borderWidth = 1, borderRadius = 5, paddingHorizontal = 7, paddingVertical = 4 },
            } },
        } })
        body:AddChild(UI.Panel { padding = 13, backgroundColor = {239,243,231,255}, borderLeftWidth = 3, borderLeftColor = C.gold, borderRadius = 7, children = {
            Label("“" .. (experience and experience.name or "眼前的本领") .. "会随着这一年的安排留下痕迹。”", { fontSize = 17, whiteSpace = "normal", lineHeight = 1.5 }),
        } })
        local statCards = {}
        for _, stat in ipairs(stats) do table.insert(statCards, UI.Panel { height = 78, padding = 8, gap = 3, backgroundColor = C.card, borderWidth = 1, borderColor = C.line, children = {
            Label(stat[1], { fontSize = 13, fontColor = C.muted }), Label(tostring(stat[2]) .. "/100", { fontSize = 22, fontWeight = "bold" }),
        } }) end
        body:AddChild(UI.Panel { borderWidth = 1, borderColor = C.line, borderRadius = 9, overflow = "hidden", children = { UI.SimpleGrid { columns = 3, gap = 0, children = statCards } } })
        body:AddChild(Card({
            UI.Row { justifyContent = "space-between", children = { Label("父母 / 养亲", { fontSize = 15, fontColor = C.muted }), Label(MemberNames(self.run, member.parents), { fontSize = 16, fontWeight = "bold" }) } },
            UI.Row { justifyContent = "space-between", children = { Label("配偶", { fontSize = 15, fontColor = C.muted }), Label((member.spouseId and State.FindMember(self.run.members, member.spouseId) and State.FindMember(self.run.members, member.spouseId).name) or "未婚", { fontSize = 16, fontWeight = "bold" }) } },
        }, { gap = 12 }))
        if not member.alive then
            body:AddChild(SectionTitle("生活与经历", nil))
            body:AddChild(Label("已故 · 生平可读", { fontSize = 16, fontWeight = "bold", fontColor = C.muted }))
            local factMap = {}
            for _, fact in ipairs(self.run.facts or {}) do factMap[fact.id] = fact end
            for _, factId in ipairs(member.factIds or {}) do
                local fact = factMap[factId]
                if fact then body:AddChild(Label(fact.text, { fontSize = 14, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.5 })) end
            end
        end
        body:AddChild(SectionTitle("目前的安排", nil))
        local currentJob = Data.Jobs[member.jobId]
        body:AddChild(Card({
            Label(member.alive and currentJob.name or "生平已封存", { fontSize = 19, fontWeight = "bold" }),
            Label(member.alive and currentJob.desc or "已故族人的关系和经历仍可查阅。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
            member.alive and not self.run.ending and Button("调整安排  →", function() section = "arrangement"; renderSection() end, { height = 44, backgroundColor = C.pale, textColor = C.green }) or Label(self.run.ending and "本局已落笔，安排已封存。" or "已故成员不再安排新的主业。", { fontSize = 13, fontColor = C.muted }),
        }))
        if member.alive and not self.run.ending then
            body:AddChild(Button("任命为族长", function()
                self:ConfirmRunAction("确认交接 · " .. member.name, "结果：开始新的族长任期，现有安排与资产保持原样。", function() return Simulation.AppointLeader(self.run, memberId, "主动交接") end, "确认交接", modal)
            end, { height = 44, backgroundColor = C.pale, textColor = C.green }))
        end
    end
    local function arrangement()
        body:AddChild(tabs())
        if not member.alive or self.run.ending then
            body:AddChild(Card({ Label("当前无法调整安排", { fontSize = 20, fontWeight = "bold" }), Label(self.run.ending and "本局已落笔，人物经历与关系均可阅读。" or "这位族人的生平已经封存。", { fontSize = 15, fontColor = C.muted, whiteSpace = "normal" }) }))
            return
        end
        body:AddChild(SectionTitle("目前的安排", "确认后写入家史"))
        body:AddChild(Card({ Label(Data.Jobs[member.jobId].name, { fontSize = 20, fontWeight = "bold" }), Label(Data.Jobs[member.jobId].desc, { fontSize = 14, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }) }, { backgroundColor = C.pale, borderColor = {151,171,118,255} }))
        body:AddChild(Label("选择新的安排", { fontSize = 18, fontWeight = "bold" }))
        body:AddChild(Label("先查看资格、年度收入或培养费用与成长，再确认写入。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }))
        for _, jobId in ipairs(Data.JobOrder) do
            local job = Data.Jobs[jobId]
            local ok, reason = Simulation.GetJobReason(member, jobId)
            body:AddChild(Button(job.name .. (ok and "" or " · " .. reason), function() self:ConfirmRunJob(memberId, jobId, modal) end, { height = 44, backgroundColor = ok and (member.jobId == jobId and C.green or C.pale) or { 235, 229, 224, 255 }, textColor = ok and (member.jobId == jobId and { 255, 255, 255, 255 } or C.green) or C.warning, fontSize = 13, textAlign = "left", paddingHorizontal = 12 }))
        end
        body:AddChild(Button("应试（10 两）", function() self:ConfirmRunAction("确认应试 · " .. member.name, "成本：10 两盘缠。结果由本人的学识与本局随机结果共同决定，并完整写入人生经历。", function() return Simulation.TakeExam(self.run, memberId) end, "确认应试", modal) end, { height = 46 }))
        body:AddChild(Button("安排婚配（12 两）", function() self:ConfirmRunAction("确认婚配 · " .. member.name, "成本：12 两安置费。结果：新配偶加入家谱，原有族人资料保持不变。", function() return Simulation.Marry(self.run, memberId) end, "确认婚配", modal) end, { height = 46, backgroundColor = C.pale, textColor = C.green }))
        body:AddChild(Button("收养孩子（8 两）", function() self:ConfirmRunAction("确认收养 · " .. member.name, "成本：8 两安置费。结果：孩子加入家谱，拥有与其他族人同等的成长与继任资格。", function() return Simulation.Adopt(self.run, memberId) end, "确认收养", modal) end, { height = 46, backgroundColor = C.pale, textColor = C.green }))
        body:AddChild(Button(member.birthPlan == false and "愿意迎来孩子" or "暂不计划生育", function()
            local nextPlan = member.birthPlan == false
            self:ConfirmRunAction("确认生育计划 · " .. member.name, nextPlan and "结果：记录为愿意迎来孩子；是否出生仍由后续年度的真实家庭条件决定。" or "结果：记录为暂缓计划，当前族人其他资料保持不变。", function() return Simulation.SetBirthPlan(self.run, memberId, nextPlan) end, "确认记录", modal)
        end, { height = 46, backgroundColor = C.pale, textColor = C.green }))
        body:AddChild(Button("任命为族长", function() self:ConfirmRunAction("确认交接 · " .. member.name, "结果：开始新的族长任期，现有安排与资产保持原样。", function() return Simulation.AppointLeader(self.run, memberId, "主动交接") end, "确认交接", modal) end, { height = 46, backgroundColor = C.pale, textColor = C.green }))
        for _, relic in ipairs(self.run.relicInstances) do
            if relic.status ~= "sold" and relic.custodianId ~= memberId then
                local definition = Data.Relic(relic.definitionId)
                body:AddChild(Button("交由" .. member.name .. "保管 · " .. definition.name, function()
                    self:ConfirmRunAction("确认更换保管人", "物件：" .. definition.name .. "\n结果：保管人改为" .. member.name .. "，当前调查进度保持不变。", function() return Simulation.TransferRelic(self.run, relic.instanceId, memberId) end, "确认托付", modal)
                end, { height = 44, backgroundColor = C.pale, textColor = C.green, fontSize = 13 }))
            end
        end
    end
    local function life()
        body:AddChild(tabs())
        body:AddChild(SectionTitle("生活与经历", nil))
        local factMap, shown = {}, false
        for _, fact in ipairs(self.run.facts or {}) do factMap[fact.id] = fact end
        for _, line in ipairs(member.biography or {}) do
            shown = true
            body:AddChild(Card({ Label(line, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }) }, { padding = 10, backgroundColor = C.paper }))
        end
        for _, factId in ipairs(member.factIds or {}) do
            local fact = factMap[factId]
            if fact then
                shown = true
                body:AddChild(Card({ Label("大晟历 " .. tostring(fact.year) .. " 年", { fontSize = 12, fontColor = C.muted }), Label(fact.text, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }) }, { padding = 10 }))
            end
        end
        if not shown then body:AddChild(Card({ Label("尚无可回看的经历。", { fontSize = 15, fontColor = C.muted }) })) end
    end
    renderSection = function()
        body:ClearChildren()
        if section == "overview" then overview() elseif section == "arrangement" then arrangement() else life() end
    end
    modal:AddContent(content)
    modal:SetFooter(Button("返回", function() modal:Close() end, { height = 46 }))
    renderSection()
    modal:Open()
end

function App:ConfirmRunJob(memberId, jobId, parentModal)
    local member = State.FindMember(self.run.members, memberId)
    local job = Data.Jobs[jobId]
    local ok, reason = false, "这位族人已不在家谱中。"
    if member then ok, reason = Simulation.GetJobReason(member, jobId) end
    if not ok or not job then self:Notify(reason, "warning"); return end
    if member.jobId == jobId then self:Notify("此人已经在做这份安排。", "info"); return end
    local money = job.money or 0
    local moneyLine = money >= 0 and ("预计本年收入 " .. tostring(money) .. " 两") or ("预计本年培养费用 " .. tostring(-money) .. " 两")
    local growthLine = job.stat and ("成长：" .. job.stat .. " +" .. tostring(job.gain or 0)) or "成长：以当前安排维持家中事务。"
    local modal = UI.Modal { title = "确认安排 · " .. member.name, size = "fullscreen", backgroundColor = C.card, borderColor = C.line, titleTextColor = C.ink, closeIconColor = C.muted, closeOnOverlay = true, onClose = function(selfModal) selfModal:Destroy() end }
    modal:AddContent(UI.Panel { padding = 14, gap = 8, children = {
        Label("改为“" .. job.name .. "”", { fontSize = 18, fontWeight = "bold" }),
        Label(job.desc, { fontSize = 14, whiteSpace = "normal", lineHeight = 1.5 }),
        Label(moneyLine .. "\n" .. growthLine, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.5 }),
    } })
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("取消", function() modal:Close() end, { flex = 1, height = 40, backgroundColor = C.pale, textColor = C.green }),
        Button("确认安排", function()
            self:RunAction(function() return Simulation.SetJob(self.run, memberId, jobId) end)
            modal:Close(); if parentModal then parentModal:Close() end
        end, { flex = 1, height = 40 }),
    } })
    modal:Open()
end

function App:BuildPeopleTab()
    local pendingByMember = {}
    for _, event in ipairs(Simulation.PendingEvents(self.run)) do
        for _, memberId in ipairs({ event.memberId, event.executorId }) do
            if memberId then pendingByMember[memberId] = (pendingByMember[memberId] or 0) + 1 end
        end
    end
    local cards = { Card({ Label("全体族人", { fontSize = 21, fontWeight = "bold" }), Label("所有成员都可独立安排；死亡不会从家谱中删除。筛选只改变当前列表显示。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }),
        UI.Row { gap = 5, children = {
            Button("全部", function() self.peopleFilter = "all"; self:Render() end, { flex = 1, height = 44, fontSize = 13, backgroundColor = self.peopleFilter == "all" and C.green or C.pale, textColor = self.peopleFilter == "all" and { 255, 255, 255, 255 } or C.green }),
            Button("在世", function() self.peopleFilter = "alive"; self:Render() end, { flex = 1, height = 44, fontSize = 13, backgroundColor = self.peopleFilter == "alive" and C.green or C.pale, textColor = self.peopleFilter == "alive" and { 255, 255, 255, 255 } or C.green }),
            Button("已故", function() self.peopleFilter = "dead"; self:Render() end, { flex = 1, height = 44, fontSize = 13, backgroundColor = self.peopleFilter == "dead" and C.green or C.pale, textColor = self.peopleFilter == "dead" and { 255, 255, 255, 255 } or C.green }),
        } },
        UI.Row { gap = 7, children = {
            UI.TextField { flex = 1, value = self.peopleQueryDraft, placeholder = "按姓名筛选，完成输入后点筛选", onChange = function(_, value) self.peopleQueryDraft = value end, onSubmit = function() self.peopleQuery = self.peopleQueryDraft; self:Render() end },
            Button("筛选", function() self.peopleQuery = self.peopleQueryDraft; self:Render() end, { width = 68, height = 44, fontSize = 13 }),
        } },
    }) }
    local matched = 0
    for _, member in ipairs(self.run.members) do
        local visible = self.peopleFilter == "all" or (self.peopleFilter == "alive" and member.alive) or (self.peopleFilter == "dead" and not member.alive)
        visible = visible and (self.peopleQuery == "" or string.find(member.name, self.peopleQuery, 1, true) ~= nil)
        if visible then
            matched = matched + 1
            local state = member.id == self.run.leaderId and "族长" or (member.alive and "在世" or "已故")
            local pendingText = pendingByMember[member.id] and (" · 待办 " .. tostring(pendingByMember[member.id])) or ""
            table.insert(cards, Card({
                Label(member.name .. " · " .. tostring(member.age) .. " 岁 · " .. state, { fontSize = 17, fontWeight = "bold", fontColor = member.alive and C.ink or C.muted, whiteSpace = "normal", lineHeight = 1.35 }),
                Label("第 " .. tostring(State.Generation(self.run.members, member.id)) .. " 代 · " .. (member.alive and Data.Jobs[member.jobId].name or "生平已封存") .. pendingText, { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }),
                Label(MemberRelationText(self.run, member), { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
                Button(self.run.ending and "查看生平" or (member.alive and "查看与安排" or "阅读生平"), function() self:OpenRunMember(member.id) end, { height = 44, fontSize = 13 }),
            }))
        end
    end
    if matched == 0 then table.insert(cards, Card({ Label("没有符合条件的族人", { fontSize = 17, fontWeight = "bold" }), Label("当前筛选未匹配姓名或生存状态。清除筛选后可回到完整家谱。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }), Button("清除筛选", function() self.peopleFilter = "all"; self.peopleQuery = ""; self.peopleQueryDraft = ""; self:Render() end, { height = 44, backgroundColor = C.pale, textColor = C.green }) })) end
    return UI.Panel { gap = 10, children = cards }
end

function App:BuildEstateTab()
    local placeButtons = {}
    if not self.run.ending then
        for _, place in ipairs(Data.Places) do
            local placeId = place.id
            table.insert(placeButtons, Button("迁居 " .. place.short .. "\n" .. place.desc .. " " .. place.burden, function()
                local fee = 18 + place.cost * 2
                self:ConfirmRunAction("确认迁居 · " .. place.short, "成本：" .. tostring(fee) .. " 两安置费。\n结果：全家迁居到" .. place.short .. "，迁居年份与费用写入家史。", function() return Simulation.MoveFamily(self.run, placeId) end, "确认迁居")
            end, {
                height = 76,
                backgroundColor = self.run.placeId == placeId and C.green or C.pale,
                textColor = self.run.placeId == placeId and { 255, 255, 255, 255 } or C.green,
                textAlign = "left",
                paddingHorizontal = 12,
                fontSize = 12,
            }))
        end
    end
    local prices = Data.RuntimeAssetCosts
    local assetActions = {}
    local assets = {
        { id = "land", label = "购田", outcome = "田地 +1 亩；年度结算多收 4 石粮。" },
        { id = "workshop", label = "置办作坊", outcome = "有在世手艺人经营时，年度结算增加 8 两。" },
        { id = "shop", label = "置办商铺", outcome = "有在世经商者经营时，年度结算增加 10 两。" },
    }
    for _, asset in ipairs(assets) do
        local item = asset
        table.insert(assetActions, Button(item.label .. " · " .. tostring(prices[item.id]) .. " 两", function()
            self:ConfirmRunAction("确认" .. item.label, "成本：" .. tostring(prices[item.id]) .. " 两。\n结果：" .. item.outcome, function() return Simulation.BuyAsset(self.run, item.id) end, "确认置办")
        end, { height = 46, fontSize = 13 }))
    end
    ---@type string[]
    local craftNames = {}
    ---@type string[]
    local tradeNames = {}
    for _, member in ipairs(self.run.members) do
        if member.alive and member.jobId == "craft" then table.insert(craftNames, member.name) end
        if member.alive and member.jobId == "trade" then table.insert(tradeNames, member.name) end
    end
    local workshopExpected = self.run.workshop and (#craftNames > 0 and "预计 +8 两" or "当前无人经营，预计 +0 两") or "尚未置办"
    local shopExpected = self.run.shop and (#tradeNames > 0 and "预计 +10 两" or "当前无人经营，预计 +0 两") or "尚未置办"
    ---@type table<any, any>
    local annualLedgers = TableValue(self.run.annualLedgers)
    local lastLedger = annualLedgers[1]
    local realized = lastLedger and ("上一年已实现产业收入 " .. tostring(lastLedger.industryIncome or 0) .. " 两 · 田产收粮 " .. tostring(lastLedger.landGrain or 0) .. " 石") or "尚未结算年度，已实现收入会在推进一年后写入账本。"
    local grainQuote = self.run.ending and nil or Simulation.GrainPurchaseQuote(self.run, 2)
    local estateChildren = {
        Label("家业与公库", { fontSize = 21, fontWeight = "bold" }),
        Label("银 " .. tostring(self.run.money) .. " 两 · 粮 " .. tostring(self.run.grain) .. " 石 · 田 " .. tostring(self.run.land) .. " 亩", { fontSize = 16 }),
        Label("住宅：" .. Data.Home(self.run.homeId).name .. " · 落脚处：" .. Data.Place(self.run.placeId).short, { fontSize = 14, fontColor = C.muted }),
        Label("作坊：" .. workshopExpected .. " · 经营人：" .. (#craftNames > 0 and table.concat(craftNames, "、") or "待安排") .. "\n商铺：" .. shopExpected .. " · 经营人：" .. (#tradeNames > 0 and table.concat(tradeNames, "、") or "待安排") .. "\n" .. realized, { fontSize = 14, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.5 }),
    }
    if self.run.ending then
        table.insert(estateChildren, Label("本局已落笔，家业与公库数值已封存。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }))
    else
        table.insert(estateChildren, Label("公市购粮", { fontSize = 17, fontWeight = "bold", marginTop = 5 }))
        if grainQuote then
            table.insert(estateChildren, Label("本地价格：购入 " .. tostring(grainQuote.amount) .. " 石需 " .. tostring(grainQuote.price) .. " 两；年度缺粮补购使用同一价格。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }))
            table.insert(estateChildren, Button("购入 " .. tostring(grainQuote.amount) .. " 石粮（" .. tostring(grainQuote.price) .. " 两）", function()
                self:ConfirmRunAction("确认购粮", "成本：" .. tostring(grainQuote.price) .. " 两。\n结果：存粮 +" .. tostring(grainQuote.amount) .. " 石，当前年度不会自动推进。", function() return Simulation.BuyGrain(self.run, grainQuote.amount) end, "确认购入")
            end, { height = 46, fontSize = 14 }))
        end
        table.insert(estateChildren, Label("置办家业", { fontSize = 17, fontWeight = "bold", marginTop = 5 }))
        table.insert(estateChildren, UI.SimpleGrid { minColumnWidth = 155, gap = 7, children = assetActions })
        table.insert(estateChildren, Button("接济邻里（15 两）", function() self:ConfirmRunAction("确认接济邻里", "成本：15 两。\n结果：接济次数与声望写入家史。", function() return Simulation.AidCommunity(self.run) end, "确认接济") end, { height = 46, backgroundColor = C.pale, textColor = C.green }))
    end
    local estateCard = Card(estateChildren)
    local moveCard = Card({
        Label("迁居", { fontSize = 18, fontWeight = "bold" }),
        Label("迁居会写入真实年份和费用，不会把家人折叠成不可操作支系。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
        self.run.ending and Label("迁居记录已封存，可在家史中回看。", { fontSize = 14, fontColor = C.muted }) or UI.SimpleGrid { minColumnWidth = 165, gap = 7, children = placeButtons },
    })
    return UI.Panel { gap = 12, children = {
        estateCard,
        moveCard,
    } }
end

function App:BuildRelicsTab()
    local stageNames = {
        idle = "尚未开始", fast = "正在快查", slow = "正在慢查", resumed = "调查已恢复", paused = "调查已暂缓",
        awaiting_executor = "等待重新指定执行人", awaiting_resolution = "线索已到", awaiting_choice = "等待决定去向",
        completed = "已修复", clue_saved = "线索暂存", work_offered = "已有修缮活", work_completed = "修缮已完成",
        work_deferred = "修缮暂缓", reunited = "故人已重逢", printed = "已刊印", passed = "已传承", closed = "已出售",
    }
    local unlocked, lockedClues = {}, {}
    local flags = TableValue(self.run.flags)
    for _, relic in ipairs(Data.Relics) do
        if self.profile.unlockedRelicIds[relic.id] then
            table.insert(unlocked, relic.name .. "（" .. tostring(relic.cost) .. " 点）")
        else
            table.insert(lockedClues, relic)
        end
    end
    local cards = {
        Card({ Label("本局物件", { fontSize = 21, fontWeight = "bold" }), Label("物件实例、保管人和执行人都属于这一局；出售不会删掉已经写入的人生与家史。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }) }),
        Card({ Label("已解锁的下局资格", { fontSize = 17, fontWeight = "bold" }), Label(#unlocked > 0 and table.concat(unlocked, "；") or "尚未解锁新的开局信物。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), Label("下局仍与其他选择共用 100 点预算。", { fontSize = 12, fontColor = C.muted }) }),
    }
    if #lockedClues > 0 then
        local clueCards = { Label("尚未解锁的线索", { fontSize = 17, fontWeight = "bold" }), Label("这些物件尚未进入开局可选池。线索只供回顾，不能在此页提前带入本局。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }) }
        for _, relic in ipairs(lockedClues) do
            table.insert(clueCards, Card({
                Label("线索 · " .. relic.name, { fontSize = 15, fontWeight = "bold", fontColor = C.muted }),
                Label("来源：" .. tostring(relic.story.source or "家中旧事") .. "。完成对应的真实经历后，资格才会写入收藏。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
            }, { backgroundColor = C.paper, borderColor = C.line }))
        end
        table.insert(cards, Card(clueCards))
    end
    for _, instance in ipairs(self.run.relicInstances) do
        local relic = Data.Relic(instance.definitionId)
        local custodian = State.FindMember(self.run.members, instance.custodianId)
        local executor = State.FindMember(self.run.members, instance.executorId)
        local actionChildren = {}
        if instance.status ~= "sold" and not self.run.ending then
            if relic.basic then
                if instance.status == "investigating" then
                    table.insert(actionChildren, Button("暂缓调查", function() self:RunAction(function() return Simulation.PauseRelicInvestigation(self.run, instance.instanceId) end) end, { height = 36, backgroundColor = C.pale, textColor = C.green }))
                elseif instance.stage == "paused" or instance.stage == "awaiting_executor" then
                    table.insert(actionChildren, Button("恢复调查", function() self:RunAction(function() return Simulation.ResumeRelicInvestigation(self.run, instance.instanceId) end) end, { height = 36 }))
                elseif instance.stage ~= "completed" then
                    table.insert(actionChildren, Button(relic.story.fast.label, function() self:RunAction(function() return Simulation.StartRelicInvestigation(self.run, instance.instanceId, "fast") end) end, { height = 36 }))
                    table.insert(actionChildren, Button(relic.story.slow.label, function() self:RunAction(function() return Simulation.StartRelicInvestigation(self.run, instance.instanceId, "slow") end) end, { height = 36, backgroundColor = C.pale, textColor = C.green }))
                end
            elseif relic.id == "newbook" and not flags.branchInvited then
                table.insert(actionChildren, Button("邀请成年旁支归家（12 两）", function() self:RunAction(function() return Simulation.InviteBranch(self.run, instance.instanceId) end) end, { height = 36, backgroundColor = C.pale, textColor = C.green }))
            elseif relic.id == "jade" and not flags.jadeReunited then
                table.insert(actionChildren, Button("发起查访（决定后花 8 两）", function() self:RunAction(function() return Simulation.StartJadeSearch(self.run, instance.instanceId) end) end, { height = 36 }))
            elseif (relic.id == "plan" or relic.id == "notes") and instance.stage == "awaiting_executor" then
                table.insert(actionChildren, Button("重新安排后续", function() self:RunAction(function() return Simulation.ResumeRelicStory(self.run, instance.instanceId) end) end, { height = 36 }))
            end
            local executorButtons = {}
            for _, member in ipairs(self.run.members) do
                if member.alive and member.age >= 18 and member.id ~= instance.executorId then
                    table.insert(executorButtons, Button("由" .. member.name .. "办理", function() self:RunAction(function() return Simulation.AssignRelicExecutor(self.run, instance.instanceId, member.id) end) end, { height = 32, backgroundColor = C.pale, textColor = C.green, fontSize = 11 }))
                end
            end
            if #executorButtons > 0 then table.insert(actionChildren, Label("指定执行人", { fontSize = 12, fontColor = C.muted })); table.insert(actionChildren, UI.Panel { gap = 5, children = executorButtons }) end
            local custodianButtons = {}
            for _, member in ipairs(self.run.members) do
                if member.alive and member.id ~= instance.custodianId then
                    table.insert(custodianButtons, Button("交由" .. member.name .. "保管", function() self:RunAction(function() return Simulation.TransferRelic(self.run, instance.instanceId, member.id) end) end, { height = 32, backgroundColor = C.pale, textColor = C.green, fontSize = 11 }))
                end
            end
            if #custodianButtons > 0 then table.insert(actionChildren, Label("更换保管人", { fontSize = 12, fontColor = C.muted })); table.insert(actionChildren, UI.Panel { gap = 5, children = custodianButtons }) end
            table.insert(actionChildren, Button("出售（" .. tostring(relic.saleValue or relic.cost * 2) .. " 两）", function() self:RunAction(function() return Simulation.SellRelic(self.run, instance.instanceId) end) end, { height = 36, backgroundColor = C.warning }))
        end
        local state = stageNames[instance.stage] or instance.stage or "尚未开始"
        local detail = "来源：" .. (instance.source or relic.story.source) .. "\n阶段：" .. state .. " · 保管人：" .. (custodian and custodian.name or "家中") .. " · 执行人：" .. (executor and executor.name or "待指定")
        if instance.dueYear then detail = detail .. "\n预计：第 " .. tostring(instance.dueYear) .. " 年后有消息" end
        if instance.remainingYears then detail = detail .. "\n暂存等待：约 " .. tostring(instance.remainingYears) .. " 年" end
        if instance.status == "sold" then table.insert(actionChildren, Label("已出售 · 本局效果停止；既有历史和下局资格仍保留。", { fontSize = 13, fontColor = C.warning })) end
        if self.run.ending then table.insert(actionChildren, Label("本局已落笔，物件状态、保管人与调查记录均已封存。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" })) end
        table.insert(cards, Card({ Label(relic.name, { fontSize = 18, fontWeight = "bold" }), Label(relic.desc, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), Label(detail, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }), UI.Panel { gap = 6, children = actionChildren } }))
    end
    if #self.run.relicInstances == 0 then table.insert(cards, Card({ Label("本局没有带入旧物。", { fontSize = 15, fontColor = C.muted }) })) end
    return UI.Panel { gap = 10, children = cards }
end

function App:BuildAnnualFooter()
    if self.run.ending then return nil end
    local pending = Simulation.PendingEvents(self.run)
    if #pending > 0 then return UI.Panel { padding = 8, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = {
        Button("有待决事件 · 去处理家事", function() self.gameTab = "family"; self:Render() end, { height = 48, fontSize = 15, backgroundColor = C.pale, textColor = C.warning }),
    } } end
    return UI.Panel { padding = 8, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = {
        Button("推进这一年", function() self:RunAction(function() return Simulation.AdvanceYear(self.run, self.profile) end) end, { height = 48, fontSize = 16 }),
    } }
end

function App:BuildHistoryTab()
    local endingCards = {}
    for _, ending in ipairs(Data.Endings) do
        ---@type table<string, any>
        local endingData = ending
        local currentEnding = self.run.ending --[[@as table<string, any>?]]
        local progress = Simulation.EndingProgress(self.run, endingData.id)
        local lines = {}
        for _, item in ipairs(progress) do table.insert(lines, ProgressText(item)) end
        ---@type Widget
        local action = nil
        if endingData.automatic then
            local autoDone = currentEnding and currentEnding.id == endingData.id
            action = Label(autoDone and "已自然写入本局终章" or (endingData.automaticHint or "自然终章会在满足条件后自动写入"), { fontSize = 12, fontColor = autoDone and C.green or C.muted, whiteSpace = "normal" })
        elseif currentEnding and currentEnding.id == endingData.id then
            action = Label("已作为本局主终章写入家史", { fontSize = 12, fontColor = C.green })
        elseif self.run.ending then
            action = Label("本局已落笔，条件保留供回顾", { fontSize = 12, fontColor = C.muted })
        elseif Simulation.IsEndingReady(self.run, endingData.id) then
            action = Button("以此落笔", function()
                self:ConfirmEnding(endingData.id)
            end, { height = 36 })
        else
            action = Label("仍可探索", { fontSize = 12, fontColor = C.muted })
        end
        table.insert(endingCards, Card({
            Label(endingData.title, { fontSize = 17, fontWeight = "bold" }),
            Label(endingData.desc, { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
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
    local termCards = {}
    local openingCalendar = TableValue(self.run.openingSnapshot).calendar or self.run.calendar
    for _, term in ipairs(self.run.leaderTerms or {}) do
        local member = State.FindMember(self.run.members, term.memberId)
        local startYear = openingCalendar + (term.startYear or 0)
        local endYear = term.endYear and (openingCalendar + term.endYear) or "至今"
        table.insert(termCards, Card({
            Label((member and member.name or "未知族人") .. " · " .. tostring(startYear) .. "—" .. tostring(endYear), { fontSize = 16, fontWeight = "bold" }),
            Label("缘由：" .. tostring(term.reason or "未记录") .. " · " .. ((term.effective and "有效任期") or "任期尚未满一年"), { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
            Button(member and "查看此人生平" or "人物记录缺失", function() if member then self:OpenRunMember(member.id) end end, { height = 44, disabled = not member, backgroundColor = C.pale, textColor = C.green }),
        }))
    end
    if #termCards == 0 then table.insert(termCards, Label("尚未记录任期。", { fontSize = 13, fontColor = C.muted })) end
    local ledgerCards = {}
    for _, ledger in ipairs(self.run.annualLedgers or {}) do
        local start = TableValue(ledger.yearStart)
        table.insert(ledgerCards, Card({
            Label("大晟历 " .. tostring(ledger.year) .. " 年账本", { fontSize = 16, fontWeight = "bold" }),
            Label("年初：银 " .. tostring(start.money or ledger.beforeMoney) .. " 两 · 粮 " .. tostring(start.grain or ledger.beforeGrain) .. " 石\n收入 " .. tostring(ledger.income or 0) .. " 两 · 培养 " .. tostring(ledger.training or 0) .. " 两 · 产业 " .. tostring(ledger.industryIncome or 0) .. " 两 · 生活 " .. tostring(ledger.livingExpense or 0) .. " 两\n粮食：需 " .. tostring(ledger.foodNeed or 0) .. " 石 · 缺 " .. tostring(ledger.foodShortfall or 0) .. " 石 · 净变 " .. tostring(ledger.netGrain or 0) .. " 石" .. (ledger.resourcesExhausted and "\n年末：公库与存粮同时归零。" or ""), { fontSize = 12, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
        }))
    end
    if #ledgerCards == 0 then table.insert(ledgerCards, Label("推进第一年后，这里会保留每一年的年初快照与结算分项。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" })) end
    local factKindNames = {
        job = "人生安排", marriage = "婚配", adoption = "收养", birth = "出生", exam = "应试", leadership = "族长交接",
        migration = "迁居", asset_purchase = "置办家业", grain_purchase = "公市购粮", community_aid = "乡里接济",
        relic = "信物故事", growth = "成长节点", annual_ledger = "年度结算",
    }
    local factCards = {}
    for _, fact in ipairs(self.run.facts or {}) do
        local participants = {}
        for _, memberId in ipairs(fact.memberIds or {}) do
            local member = State.FindMember(self.run.members, memberId)
            if member then table.insert(participants, Button(member.name, function() self:OpenRunMember(member.id) end, { height = 40, fontSize = 12, backgroundColor = C.pale, textColor = C.green })) end
        end
        table.insert(factCards, Card({
            Label("大晟历 " .. tostring(fact.year) .. " 年 · " .. (factKindNames[fact.kind] or tostring(fact.kind)), { fontSize = 14, fontWeight = "bold", fontColor = C.green }),
            Label(fact.text, { fontSize = 14, whiteSpace = "normal", lineHeight = 1.5 }),
            Label("参与人", { fontSize = 12, fontColor = C.muted }),
            #participants > 0 and UI.SimpleGrid { minColumnWidth = 120, gap = 5, children = participants } or Label("全家记录", { fontSize = 13, fontColor = C.muted }),
        }, { padding = 10, gap = 6 }))
    end
    if #factCards == 0 then table.insert(factCards, Label("尚无带参与人的事实记录。年度推进、人生安排和家业动作会从这里开始保留。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" })) end
    local endingOverview = {}
    if self.run.ending then
        local record = self.run.ending --[[@as table<string, any>]]
        local snapshot = { Label("本局终章 · " .. tostring(record.title), { fontSize = 18, fontWeight = "bold" }), Label(record.automatic and "自然终局" or "确认的主终章", { fontSize = 12, fontColor = C.muted }) }
        for _, item in ipairs(record.evidence or {}) do table.insert(snapshot, Label(EndingEvidenceText(self.run, item), { fontSize = 12, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 })) end
        if #(record.closingEventIds or {}) > 0 then table.insert(snapshot, Label("终局时关闭 " .. tostring(#record.closingEventIds) .. " 个待决事件。", { fontSize = 12, fontColor = C.muted })) end
        table.insert(endingOverview, Card(snapshot))
    else
        table.insert(endingOverview, Card({ Label("终章资格", { fontSize = 18, fontWeight = "bold" }), Label("条件达成后仍可继续经营；由家主确认一条发展终章才会封存本局。", { fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }) }))
    end
    local selector = UI.Row { gap = 6, children = {
        Button("任期", function() self.historySection = "terms"; self:Render() end, { flex = 1, height = 44, fontSize = 13, backgroundColor = self.historySection == "terms" and C.green or C.pale, textColor = self.historySection == "terms" and { 255, 255, 255, 255 } or C.green }),
        Button("年鉴", function() self.historySection = "annals"; self:Render() end, { flex = 1, height = 44, fontSize = 13, backgroundColor = self.historySection == "annals" and C.green or C.pale, textColor = self.historySection == "annals" and { 255, 255, 255, 255 } or C.green }),
        Button("终章", function() self.historySection = "endings"; self:Render() end, { flex = 1, height = 44, fontSize = 13, backgroundColor = self.historySection == "endings" and C.green or C.pale, textColor = self.historySection == "endings" and { 255, 255, 255, 255 } or C.green }),
    } }
    local sectionContent = {}
    if self.historySection == "terms" then
        sectionContent = { Card({ Label("历任族长", { fontSize = 18, fontWeight = "bold" }), Label("任期和人物经历引用同一份事实记录。", { fontSize = 13, fontColor = C.muted }), UI.Panel { gap = 8, children = termCards } }) }
    elseif self.historySection == "endings" then
        sectionContent = { UI.Panel { gap = 12, children = endingOverview }, Card({ Label("十四条终章", { fontSize = 18, fontWeight = "bold" }), Label("发展终章十二条；全员离世或年末钱粮同归零时自动写入。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), UI.Panel { gap = 8, children = endingCards } }) }
    else
        sectionContent = {
            Card({ Label("事实记录 · " .. tostring(#factCards) .. " 条", { fontSize = 18, fontWeight = "bold" }), Label("来源、参与人与人物生平共用同一份记录；点参与人可直接回看。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), UI.Panel { gap = 8, children = factCards } }),
            Card({ Label("年度账本", { fontSize = 18, fontWeight = "bold" }), Label("每年结算冻结年初资源与收入、培养、生活、粮食分项。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }), UI.Panel { gap = 8, children = ledgerCards } }),
            Card({ Label("年鉴 · " .. tostring(#self.run.logs) .. " 条 · 第 " .. tostring(self.historyPage) .. "/" .. tostring(pageCount) .. " 页", { fontSize = 18, fontWeight = "bold" }), pager, UI.Panel { gap = 8, children = logCards } }),
        }
    end
    return UI.Panel { gap = 12, children = {
        Card({ Label("家史", { fontSize = 21, fontWeight = "bold" }), Label("家史全量保留，按新到旧分页。", { fontSize = 13, fontColor = C.muted }),
            UI.Row { gap = 8, children = {
                Button("导出本局", function() self:Export() end, { flex = 1 }),
                Button("导入备份", function() self:OpenImport() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
                Button("新立家谱", function() self:PrepareNewRun() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
            } },
        }),
        selector,
        UI.Panel { gap = 12, children = sectionContent },
    } }
end

function App:BuildGame()
    local builders = { family = function() return self:BuildFamilyTab() end, people = function() return self:BuildPeopleTab() end, estate = function() return self:BuildEstateTab() end, relics = function() return self:BuildRelicsTab() end, history = function() return self:BuildHistoryTab() end }
    local openingSnapshot = TableValue(self.run.openingSnapshot)
    local familyName = tostring(openingSnapshot["family"] or "无名") .. "氏"
    local children = {
        self:BuildHeader(familyName .. " · 立家第 " .. tostring(self.run.yearIndex + 1) .. " 年", Data.WORLD_NAME .. "历 " .. tostring(self.run.calendar) .. " 年 · " .. Data.Place(self.run.placeId).short),
        self:BuildRunStatusBar(),
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
        nativeMenuInset = true,
        backgroundColor = C.dark,
        alignItems = "center",
        children = { phoneFrame },
    }
    UI.SetRoot(self.root, true)
end

return App
