local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Opening = require "Jiaye.Opening"
local OpeningView = require "Jiaye.OpeningView"
local OpeningEditor = require "Jiaye.OpeningEditor"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"
local Economy = require "Jiaye.Economy"
local FamilyTree = require "Jiaye.FamilyTree"
local MemberView = require "Jiaye.MemberView"
local HistoryView = require "Jiaye.HistoryView"
local EventView = require "Jiaye.EventView"
local RelicsView = require "Jiaye.RelicsView"
local RelicV12View = require "Jiaye.RelicV12View"
local RelicState = require "Jiaye.RelicState"
local OriginView = require "Jiaye.OriginView"
local ModalLayout = require "Jiaye.ModalLayout"

local App = {}
App.__index = App

local C = {
    paper = V7.Colors.paper, card = V7.Colors.paperLight, ink = V7.Colors.ink,
    muted = V7.Colors.secondary, line = V7.Colors.rule, green = V7.Colors.primary,
    dark = V7.Colors.ink, pale = V7.Colors.selected, warning = V7.Colors.danger, gold = V7.Colors.gold,
}

local function Label(text, props)
    return Visual.Text(text, props)
end

local function Button(text, onClick, props)
    props = props or {}
    props.role = props.role or (props.backgroundColor == C.warning and "danger" or (props.backgroundColor == C.pale or props.backgroundColor == C.paper) and "secondary" or "primary")
    props.height = math.max(44, props.height or 48)
    props.fontSize = math.max(14, props.fontSize or 16)
    props.backgroundColor = nil
    props.textColor = nil
    return Visual.Button(text, onClick, props)
end

local function Card(children, props)
    return Visual.Card(children, props)
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

---@param value unknown
---@return table<any, any>
local function TableValue(value)
    return type(value) == "table" and value or {}
end

local function HasId(values, id)
    for _, value in ipairs(values or {}) do if value == id then return true end end
    return false
end

local function MemberRelationText(run, member)
    local relations = {}
    if member.id == run.leaderId then table.insert(relations, "现任族长") end
    local parentNames = {}
    for _, parentId in ipairs(member.parents or {}) do
        local parent = State.FindMember(run.members, parentId)
        if parent then table.insert(parentNames, parent.name) end
    end
    if #parentNames > 0 then table.insert(relations, "亲长：" .. table.concat(parentNames, "、")) end
    local spouse = member.spouseId and State.FindMember(run.members, member.spouseId)
    if spouse then table.insert(relations, "配偶：" .. spouse.name) end
    for _, candidate in ipairs(run.members) do
        for _, parentId in ipairs(candidate.parents or {}) do
            if parentId == member.id then table.insert(relations, "子女：" .. candidate.name) end
        end
    end
    return #relations > 0 and table.concat(relations, " · ") or "家谱关系待续"
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
    self.familyGeneration = 0
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
    self.familyGeneration = 0; self.peopleFilter = "all"
    self.openingEditDraft = nil; self.memberEditing = nil; self.memberLifePages = {}; self.historyPages = {}
    self.previousDraft = nil; self.editBackup = nil; self.houseUndo = nil; self.openingView = "summary"; self.undo = {}; self.historyPage = 1; self.peopleQuery = ""; self.peopleQueryDraft = ""; self.historySection = "annals"; self.storageBlocked = false; self.openingGenerationFailed = false
    self.saveMessage = status == "recovered" and message or ""
    self.screen = self.run and "game" or "opening"
    self:Render(); self:Notify(message, status == "recovered" and "warning" or "success")
end

function App:Export()
    local raw, message = State.Export(self.profile, self.previousDraft or self.draft, self.run)
    if not raw then self:Notify(message, "error"); return end
    local externalPath = State.ExternalExportPath()
    local backupField = UI.TextField {
        value = raw, maxLength = math.max(#raw, 1), height = 180, fontSize = 12,
        placeholder = "家谱备份 JSON",
    }
    local modal = ModalLayout.New("保存家谱备份", { sheet = "full", closeOnOverlay = true })
    local body = UI.Panel { gap = 10 }
    body:AddChild(Label(message, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }))
    body:AddChild(Label("备份共 " .. tostring(#raw) .. " 字节。跨应用、跨设备传递以用户文档中的 JSON 文件为准：可打开文件后用系统文件应用复制、发送或保存。页面复制只作便捷尝试，游戏内回读不能证明外部应用已收到。", { fontSize = 15, whiteSpace = "normal", lineHeight = 1.5 }))
    body:AddChild(externalPath and Label("文件位置：" .. externalPath, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }) or Label("当前环境没有用户文档目录，请使用下方可见备份内容完成传递。", { fontSize = 13, fontColor = C.warning, whiteSpace = "normal" }))
    body:AddChild(Label("备份内容（可长按或点入后全选）：", { fontSize = 14, fontWeight = "bold" }))
    body:AddChild(backupField)
    body:AddChild(Button("打开用户文档备份", function()
            local opened, _, openMessage = State.OpenExternalExport()
            self:Notify(openMessage, opened and "success" or "warning")
        end, { width = "100%", role = "secondary" }))
    body:AddChild(Button("尝试系统复制", function()
            ui:SetUseSystemClipboard(true)
            ui:SetClipboardText(raw)
            if ui:GetClipboardText() ~= raw then self:Notify("系统复制未能在游戏内回读，请打开用户文档备份。", "warning"); return end
            self:Notify("游戏内部已回读复制内容；外部读取请以用户文档文件为准。", "info")
        end, { width = "100%", role = "secondary" }))
    modal:AddContent(ModalLayout.Scroll(body))
    modal:Open()
    backupField:SelectAll()
end

function App:OpenMenu()
    local modal = ModalLayout.New("家谱事务", { sheet = "menu", closeOnOverlay = true })
    modal:AddContent(ModalLayout.Scroll(UI.Panel { gap = 8, children = {
        Button("保存家谱", function() modal:Close(); self:Save() end, { width = "100%" }),
        Button("导出备份", function() modal:Close(); self:Export() end, { width = "100%", role = "secondary" }),
        Button("恢复本机备份", function()
            local candidate, message, status = State.ReadExport()
            if not candidate then self:Notify(message, "error"); return end
            modal:Close(); self:ConfirmImport(candidate, message, status)
        end, { width = "100%", role = "secondary" }),
        Button("从用户文档导入", function() modal:Close(); self:ImportExternal() end, { width = "100%", role = "secondary" }),
        Button("导入备份", function() modal:Close(); self:OpenImport() end, { width = "100%", role = "secondary" }),
        Button("立新家谱", function() modal:Close(); self:PrepareNewRun() end, { width = "100%", role = "secondary" }),
    } }))
    modal:Open()
end

function App:ImportExternal()
    if self.unsaved then self:Notify("当前安排尚未保存，请先重试保存或导出，避免覆盖内存中的进度。", "warning"); return end
    local candidate, message, status = State.ReadExternalExport()
    if not candidate then self:Notify(message, "error"); return end
    self:ConfirmImport(candidate, message, status)
end

function App:OpenImport()
    if self.unsaved then self:Notify("当前安排尚未保存，请先重试保存或导出，避免覆盖内存中的进度。", "warning"); return end
    self.importRaw = ""
    local modal = ModalLayout.New("导入家业备份", { sheet = "full", closeOnOverlay = true })
    local body = UI.Panel { gap = 10 }
    body:AddChild(Label("粘贴完整 JSON 备份，接收后保留在页面中并显示文件长度。系统会检查版本、结构和人物/物件引用；确认前不会改动当前进度。也可返回家谱事务，从用户文档备份直接读取。", { fontSize = 15, whiteSpace = "normal", lineHeight = 1.55 }))
    local receipt = Label("尚未接收备份", { fontSize = 14, fontColor = C.muted })
    body:AddChild(UI.TextField {
        value = "", placeholder = "在此粘贴完整备份", maxLength = 15000000, height = 180, fontSize = 12,
        onChange = function(_, value)
            if value == "" then return end
            self.importRaw = value
            receipt:SetText("已接收 " .. tostring(#value) .. " 字节，等待校验")
        end,
    })
    body:AddChild(receipt)
    modal:AddContent(ModalLayout.Scroll(body))
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("校验并预演", function()
            local candidate, message, status = State.PreflightImport(self.importRaw)
            if not candidate then self:Notify(message, "error"); return end
            modal:Close(); self:ConfirmImport(candidate, message, status)
        end, { flex = 1, height = 46 }),
        Button("取消", function() modal:Close() end, { flex = 1, height = 46, backgroundColor = C.pale, textColor = C.green }),
    } })
    modal:Open()
end

function App:ConfirmImport(candidate, previewMessage, status)
    local modal = ModalLayout.New("确认替换当前进度", { sheet = "confirm", closeOnOverlay = false })
    local body = UI.Panel { gap = 10, children = {
        Label(previewMessage, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.55 }),
        Label("确认后写入新的可回读存档；当前进度在写入失败时保持原样。重复确认同一份备份只保留一份结果。", { fontSize = 14, whiteSpace = "normal", lineHeight = 1.5, fontColor = C.muted }),
    } }
    modal:AddContent(ModalLayout.Scroll(body))
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("确认导入", function()
            local ok, message, result = State.CommitImport(candidate)
            if not ok then self:Notify(message, "error"); return end
            local loaded, loadMessage = State.Load()
            if not loaded then self:Notify("导入写入后无法读取，请保留备份并重试。", "error"); return end
            self.profile, self.draft, self.run = loaded.profile, loaded.draft, loaded.run
            self.openingEditDraft = nil; self.memberEditing = nil; self.memberLifePages = {}; self.historyPages = {}
            self.familyGeneration = 0; self.peopleFilter = "all"
            self.previousDraft = nil; self.editBackup = nil; self.houseUndo = nil; self.undo = {}; self.historyPage = 1
            self.peopleQuery = ""; self.peopleQueryDraft = ""; self.historySection = "annals"; self.storageBlocked = false
            self.unsaved = false; self.saveMessage = ""; self.openingGenerationFailed = false
            self.screen = self.run and "game" or "opening"
            modal:Close(); self:Render(); self:Notify(result == "duplicate" and message or (message .. " " .. loadMessage), "success")
        end, { flex = 1, height = 46 }),
        Button("保留当前进度", function() modal:Close() end, { flex = 1, height = 46, backgroundColor = C.pale, textColor = C.green }),
    } })
    modal:Open()
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
    self.openingEditDraft = nil; self.memberEditing = nil
    self.screen = "opening"; self.openingView = "summary"; self.openingFeedback = ""; self:Render()
end

function App:CancelNewRun()
    if not self.previousDraft then return end
    self.draft = self.previousDraft; self.previousDraft = nil; self.undo = {}; self.editBackup = nil; self.houseUndo = nil
    self.openingEditDraft = nil; self.memberEditing = nil
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
        local submittedDraft = State.Copy(self.draft)
        local created, candidate, errors = pcall(State.NewRun, submittedDraft, self.profile)
        if not created or type(candidate) ~= "table" then
            submitted = false
            self:Notify(not created and tostring(candidate) or (type(errors) == "table" and table.concat(errors, " ") or "开局草案无效。"), "error")
            return
        end
        -- 先验证写入，再切换当前局；失败时旧 run、收藏和正在展示的草案都在。
        local written, ok, message = pcall(State.Save, self.profile, submittedDraft, candidate)
        if not written or not ok then
            submitted = false
            self.saveMessage = "新局未开始。" .. tostring(written and message or ok)
            self:Render(); self:Notify(self.saveMessage, "error"); return
        end
        self.run = candidate; self.draft = submittedDraft; self.previousDraft = nil; self.saveMessage = ""
        self.familyGeneration = 0; self.peopleFilter = "all"
        self.openingEditDraft = nil; self.memberEditing = nil; self.memberLifePages = {}; self.historyPages = {}
        self.screen = "game"; self.gameTab = "family"; self.historyPage = 1; self.undo = {}
        self:Render(); self:Notify("家谱开篇。已保留收藏，并保存当前家谱。", "success")
    end
    if not self.run then commit(); return end
    self.startConfirmationOpen = true
    local modal = ModalLayout.New("开始新家谱？", {
        sheet = "confirm",
        backgroundColor = C.card, borderColor = C.line, titleTextColor = C.ink, closeIconColor = C.muted,
        onClose = function(selfModal)
            self.startConfirmationOpen = false; selfModal:Destroy()
        end,
    })
    modal:AddContent(Label("当前家谱将由眼前这份新草案替换。已解锁收藏与终章档案保留；如需长期留存旧局，请先导出。", { whiteSpace = "normal", fontSize = 16 }))
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("取消", function() modal:Close() end, { flex = 1, backgroundColor = C.pale, textColor = C.green }),
        Button("确认开始", function() modal:Close(); commit() end, { flex = 1 }),
    } })
    modal:Open()
end

function App:RunAction(fn)
    if self.run and self.run.ending then self:Notify("本局已落笔，只能回顾家史。", "warning"); return false end
    if self.storageBlocked then self:Notify("请先恢复可读取的存档，再继续安排。", "warning"); return false end
    if self.unsaved then self:Notify("上一项安排尚未保存，请重试保存；无需重复安排。", "warning"); return false end
    if self.actionBusy then
        self:Notify("上一项安排正在写入，请勿重复操作。", "warning")
        return false
    end
    local previousRun, previousProfile = self.run, self.profile
    self.run, self.profile = State.Copy(previousRun), State.Copy(previousProfile)
    self.actionBusy = true
    local executed, ok, message = pcall(fn, self.run, self.profile)
    self.actionBusy = false
    if not executed or not ok then
        self.run, self.profile = previousRun, previousProfile
        if not executed then
            print("家业操作失败：" .. tostring(ok))
            self:Notify("这次操作未提交，钱粮和家谱保持原样。" .. tostring(ok), "error")
        else self:Notify(message, "warning") end
        return false
    end
    local saved, result = pcall(function() return self:Save() end)
    if not saved then
        self.unsaved = true
        self.saveMessage = "当前安排已在内存中保留，存档未完成：" .. tostring(result)
        self:Render(); self:Notify(self.saveMessage, "error")
    elseif result then self:Notify(message, "success") end
    return true
end

function App:ConfirmRunAction(title, detail, action, confirmText, parentModal, artEvent)
    if self.run and self.run.ending then self:Notify("本局已落笔，只能回顾家史。", "warning"); return end
    local modal = ModalLayout.New(title, { backgroundColor = C.card, borderColor = C.line,
        sheet = "confirm",
        titleTextColor = C.ink, closeIconColor = C.muted, closeOnOverlay = true,
        onClose = function(selfModal) selfModal:Destroy() end })
    local content = UI.Panel { padding = 12, gap = 12, children = {
        Label(detail, { fontSize = 15, whiteSpace = "normal", lineHeight = 1.55 }),
        Label("确认后会立刻写入本局家谱、账本与年鉴。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
    } }
    if artEvent then content:AddChild(Visual.EventImage(artEvent)) end
    if ModalLayout.NeedsScroll(detail, artEvent) then
        modal:AddContent(ModalLayout.Scroll(content))
    else
        modal:AddContent(content)
    end
    local submitted = false
    modal:SetFooter(UI.Row { gap = 8, children = {
        Button("返回", function() modal:Close() end, { flex = 1, height = 46, backgroundColor = C.pale, textColor = C.green }),
        Button(confirmText or "确认执行", function()
            if submitted then return end
            submitted = true
            if self:RunAction(action) then
                modal:Close()
                if parentModal then parentModal:Close() end
            else submitted = false end
        end, { flex = 1, height = 46 }),
    } })
    modal:Open()
end

function App:ConfirmEnding(endingId)
    local ending = Data.Ending(endingId)
    if not ending or ending.automatic then self:Notify("这条终章不能由家主确认。", "warning"); return end
    if not Simulation.IsEndingReady(self.run, endingId) then self:Notify("条件尚未满足。", "warning"); return end
    local conditionLines = { ending.desc, "以下经历会写入本局终章。确认后，人物、家业、事件和信物将进入只读状态。" }
    ---@type table?
    local opportunity = self.run.originOpportunity
    if opportunity and opportunity.status == "active" and (opportunity.deposit or 0) > 0 then
        table.insert(conditionLines, "旧卷尚有" .. tostring(opportunity.deposit) .. "两押金未归还；现在落笔会将合同封存，押金不会自动兑现。")
    end
    for _, item in ipairs(Simulation.EndingProgress(self.run, endingId)) do
        table.insert(conditionLines, ProgressText(item))
    end
    self:ConfirmRunAction("落笔 · " .. ending.title, table.concat(conditionLines, "\n\n"), function()
        return Simulation.ClaimEnding(self.run, endingId, self.profile)
    end, "确认落笔")
end

function App:BuildHeader(title, subtitle)
    return UI.Panel {
        height = 54, flexDirection = "row", alignItems = "center", justifyContent = "space-between", paddingHorizontal = 14,
        flexShrink = 0, borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            UI.Row { gap = 9, flex = 1, alignItems = "center", children = {
                Visual.Decor("seal_square", { width = 30, height = 30 }),
                Label(title, { fontSize = 20, fontFamily = "serif" }),
                Label(subtitle, { fontSize = 12, fontColor = C.muted }),
            } },
            Button(self.unsaved and "重试保存" or "···", function() if self.unsaved then self:Save() else self:OpenMenu() end end, { width = self.unsaved and 84 or 44, height = 44, fontSize = 20, role = "secondary", paddingHorizontal = 0 }),
        },
    }
end

function App:GetRunOverview()
    local living, foodNeed = 0, 0
    for _, member in ipairs(self.run.members) do
        if member.alive then
            living = living + 1
            foodNeed = foodNeed + (State.IsAdult(member) and 2 or 1)
        end
    end
    return living, foodNeed
end

function App:BuildRunStatusBar()
    return UI.Row {
        height = 38, flexShrink = 0, paddingHorizontal = 14, gap = 6, alignItems = "center",
        borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            Visual.Icon("money", 16), Label(tostring(self.run.money) .. " 两", { fontSize = 15 }),
            Visual.Icon("grain", 16), Label(tostring(self.run.grain) .. " 石", { fontSize = 15 }),
            UI.Panel { flex = 1 },
            Label(Data.WORLD_NAME .. "历 " .. tostring(self.run.calendar) .. " 年", { fontSize = 12, fontColor = C.muted }),
        },
    }
end

function App:BuildCover()
    local actions = {
        UI.Row { gap = 10, alignItems = "center", children = {
            Visual.Decor("seal_square", { width = 30, height = 30 }),
            UI.Panel { flex = 1, gap = 1, children = {
                Label("家业", { fontSize = 29, fontWeight = "bold", fontFamily = "serif" }),
                Label("凡世王朝 · " .. Data.WORLD_NAME, { fontSize = 13, fontColor = C.muted }),
            } },
        } },
        Label("一部由选择写成的家谱", { fontSize = 18, fontColor = C.green, marginTop = 18, fontFamily = "serif" }),
        Label("生成一户人家，看看家人、家底和首年预计。点击想调整的对象，便能写下家谱的开篇。", { fontSize = 15, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.65 }),
        UI.Panel { gap = 7, padding = 12, backgroundColor = C.card, borderWidth = 1, borderColor = C.line, borderRadius = 10, children = {
            UI.Row { gap = 8, children = {
                Label("完整家谱", { fontSize = 14, fontWeight = "bold", fontColor = C.green }),
                Label("人口、亲缘与主业一并生成", { fontSize = 13, fontColor = C.muted }),
            } },
            UI.Row { gap = 8, children = {
                Label("钱粮预估", { fontSize = 14, fontWeight = "bold", fontColor = C.green }),
                Label("首年净变化和总分可直接核对", { fontSize = 13, fontColor = C.muted }),
            } },
            UI.Row { gap = 8, children = {
                Label("家谱延续", { fontSize = 14, fontWeight = "bold", fontColor = C.green }),
                Label("人生、信物与决定都会留下记录", { fontSize = 13, fontColor = C.muted }),
            } },
        } },
    }
    if self.openingGenerationFailed then
        table.insert(actions, Label(self.openingFeedback, { fontSize = 14, fontColor = C.warning, whiteSpace = "normal", lineHeight = 1.5 }))
    end
    table.insert(actions, Button("立一部家谱", function() self:PrepareNewRun() end, { height = 52, fontSize = 17, marginTop = 10 }))
    table.insert(actions, Button(self.run and "继续家谱" or "读取最近存档", function() self:Load() end, { height = 46, backgroundColor = C.pale, textColor = C.green }))
    table.insert(actions, Button("从用户文档导入", function() self:ImportExternal() end, { height = 44, backgroundColor = C.pale, textColor = C.green }))
    table.insert(actions, Button("导入备份", function() self:OpenImport() end, { height = 44, backgroundColor = C.pale, textColor = C.green }))
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.paper, justifyContent = "center", padding = 22, children = {
        Visual.Decor("clouds", { position = "absolute", top = 12, right = 0, width = 190, height = 76, opacity = 0.2, pointerEvents = "none" }),
        Visual.Decor("mountains", { position = "absolute", bottom = 0, left = 0, width = "100%", height = 220, opacity = 0.2, pointerEvents = "none" }),
        UI.Panel { gap = 14, children = actions },
    } }
end

function App:BuildOpening()
    return OpeningView.Build(self)
end

function App:BuildGameNav()
    local tabs = { { id = "family", text = "家族", icon = "family" }, { id = "people", text = "族人", icon = "people" }, { id = "estate", text = "家业", icon = "estate" }, { id = "relics", text = "藏阁", icon = "relics" }, { id = "history", text = "家史", icon = "history" } }
    local children = {}
    for _, tab in ipairs(tabs) do
        local active = self.gameTab == tab.id
        table.insert(children, UI.Button { flex = 1, height = 56, paddingHorizontal = 4, paddingVertical = 4, gap = 2, flexDirection = "column", alignItems = "center", justifyContent = "center",
            backgroundColor = { 0, 0, 0, 0 }, hoverBackgroundColor = C.pale, pressedBackgroundColor = C.pale,
            borderRadius = 0, borderWidth = 0, borderBottomWidth = active and 2 or 0, borderBottomColor = C.green,
            onClick = function() self.gameTab = tab.id; self:Render() end,
            children = { Visual.Icon(tab.icon, 22, active and "ink" or "muted"), Label(tab.text, { fontSize = 12, fontColor = active and C.green or C.muted }) },
        })
    end
    return UI.Panel { flexShrink = 0, paddingHorizontal = 5, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = { UI.Row { children = children } } }
end

function App:BuildPendingEvent(event)
    return EventView.Card(self, event)
end

function App:BuildFamilyMap()
    return FamilyTree.Build(self)
end

function App:OpenRelic(instanceId)
    if RelicState.IsNew(self.run) then return RelicV12View.Open(self, instanceId) end
    for _, instance in ipairs(self.run.relicInstances) do
        if instance.instanceId == instanceId then return EventView.OpenRelic(self, instance) end
    end
end

function App:BuildFamilyTab()
    local leader = State.FindMember(self.run.members, self.run.leaderId)
    local _, foodNeed = self:GetRunOverview()
    local pending = Simulation.PendingEvents(self.run)
    local completedEnding = TableValue(self.run.ending)
    local period = Data.Period(self.run.eraId)
    local children = {
        UI.Row { justifyContent = "space-between", children = {
            Label(Data.Place(self.run.placeId).short .. " · " .. period.name, { fontSize = 13, fontColor = C.muted }),
            Label(leader and ("第 " .. tostring(#self.run.leaderTerms) .. " 任族长 · " .. leader.name) or "待定族长", { fontSize = 12, fontColor = C.muted }),
        } },
        Visual.House(self.run.homeId, V7.HouseState(self.run), { height = 116, borderWidth = 1, borderColor = C.gold }),
    }
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
        for _, event in ipairs(pending) do table.insert(children, self:BuildPendingEvent(event)) end
    else
        for _, instance in ipairs(self.run.relicInstances) do
            local newRelics = RelicState.IsNew(self.run)
            local relic = newRelics and RelicState.Form(instance) or Data.Relic(instance.definitionId)
            if instance.status == "held" and (newRelics or relic.basic and instance.stage ~= "completed" and instance.rewardState ~= "granted") then
                table.insert(children, Card({ UI.Row { gap = 10, alignItems = "center", children = {
                    Visual.Relic(newRelics and relic.id or instance.definitionId, 42),
                    UI.Panel { flex = 1, gap = 4, children = {
                        Label(relic.name, { fontSize = 18 }),
                        Label("家传旧物 · " .. (newRelics and relic.description or relic.desc), { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
                    } },
                    Visual.Icon("forward", 18),
                } } }, { onClick = function() self:OpenRelic(instance.instanceId) end, borderColor = C.gold }))
                break
            end
        end
        local guidance = self.run.grain < foodNeed and "存粮偏少，可安排耕作或在家业中购粮。" or "本年安排会持续；点家人头像即可调整。"
        table.insert(children, Label(guidance, { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }))
    end
    for _, task in ipairs(self.run.relicTasks or {}) do
        if task.status == "ready" then
            table.insert(children, Card({
                Label("信物已有结果", { fontSize = 17, fontColor = C.green }),
                Label("结果保留在藏阁，可继续推进年度。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
                Button("查看并决定", function() self:OpenRelic(task.instanceId) end, { height = 44, role = "secondary" }),
            }))
        end
    end
    local originCard = OriginView.Card(self)
    if originCard then table.insert(children, originCard) end
    table.insert(children, self:BuildFamilyMap())
    for _, habit in pairs(self.run.habitFormations or {}) do
        local status = ({ active = "已形成", paused = "暂歇", inactive = "失效" })[habit.status] or habit.status
        local effect = RelicState.IsNew(self.run) and " · 有效读书年度学识 +1" or "（原型，无额外属性）"
        table.insert(children, Label("家风 · " .. habit.name .. " · " .. status .. effect, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }))
    end
    local ledger = TableValue(self.run.annualLedgers)[1]
    if ledger then
        local function signed(value) return (value >= 0 and "+" or "") .. tostring(value) end
        table.insert(children, Card({
            Label(tostring(ledger.year) .. " 年 · 已结算", { fontSize = 13, fontColor = C.muted }),
            Label("银 " .. signed(ledger.netMoney) .. " 两 · 粮 " .. signed(ledger.netGrain) .. " 石", { fontSize = 17 }),
            Button("翻看年度账本", function() self.gameTab = "history"; self.historySection = "ledgers"; self.historyPage = 1; self:Render() end, { role = "secondary", height = 44 }),
        }))
    end
    return UI.Panel { gap = 10, children = children }
end

function App:OpenRunMember(memberId)
    return MemberView.Open(self, memberId)
end

function App:ConfirmRunJob(memberId, jobId, parentModal)
    local member = State.FindMember(self.run.members, memberId)
    local job = Data.Jobs[jobId]
    local ok, reason = false, "这位族人已不在家谱中。"
    if member then ok, reason = Simulation.GetJobReason(member, jobId) end
    if not ok or not job then self:Notify(reason, "warning"); return end
    if member.jobId == jobId then self:Notify("此人已经在做这份安排。", "info"); return end
    local quote, issue = Economy.JobQuote(self.run, memberId, jobId)
    if not quote then self:Notify(issue, "error"); return end
    local function signed(value) return (value >= 0 and "+" or "") .. tostring(value) end
    local detail = "改为“" .. job.name .. "”\n" .. job.desc
        .. "\n基础银钱：" .. signed(quote.baseMoney) .. " 两"
        .. "\n本年预计：银 " .. signed(quote.money) .. " 两 · 粮 " .. signed(quote.grain) .. " 石"
        .. "\n成长：" .. quote.growthText
        .. "\n已计入当前时世、地区、能力与来历修正；不含突发事件及全家生活开支。"
    self:ConfirmRunAction("安排 · " .. member.name, detail, function()
        return Simulation.SetJob(self.run, memberId, jobId)
    end, "确认安排", parentModal)
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
                UI.Row { gap = 12, alignItems = "center", children = {
                    Visual.Portrait(member, { size = 60, leader = member.id == self.run.leaderId }),
                    UI.Panel { flex = 1, gap = 4, children = {
                        Label(member.name, { fontSize = 21, fontWeight = "bold", fontColor = member.alive and C.ink or C.muted, whiteSpace = "normal" }),
                        Label(tostring(member.age) .. " 岁 · " .. state .. " · 第 " .. tostring(State.Generation(self.run.members, member.id)) .. " 代", { fontSize = 13, fontColor = C.muted }),
                        Label((member.alive and Data.Jobs[member.jobId].name or "生平已封存") .. pendingText, { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }),
                    } },
                } },
                Label(MemberRelationText(self.run, member), { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
                Button(self.run.ending and "查看生平" or (member.alive and "查看与安排" or "阅读生平"), function() self:OpenRunMember(member.id) end, { height = 44, fontSize = 15, role = "secondary", pointerEvents = "none" }),
            }, {
                pointerEvents = "box-only",
                onClick = function() self:OpenRunMember(member.id) end,
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
            local current = self.run.placeId == placeId
            local quote = current and { cost = 0 } or assert(Simulation.MigrationQuote(self.run, placeId))
            local affordable = self.run.money >= quote.cost
            local label = current and ("当前居所 · " .. place.short .. "\n" .. place.desc) or ("迁居 " .. place.short .. " · " .. tostring(quote.cost) .. " 两\n" .. place.desc .. " " .. place.burden)
            table.insert(placeButtons, Button(label, function()
                local currentQuote, reason = Simulation.MigrationQuote(self.run, placeId)
                if not currentQuote then self:Notify(reason, "warning"); return end
                local benefit = currentQuote.discount > 0 and ("\n通家玉佩抵扣 " .. tostring(currentQuote.discount) .. " 两，本次实迁后进入冷却。") or ""
                self:ConfirmRunAction("确认迁居 · " .. place.short, "成本：" .. tostring(currentQuote.cost) .. " 两安置费。" .. benefit .. "\n结果：全家迁居到" .. place.short .. "，迁居年份与费用写入家史。", function() return Simulation.MoveFamily(self.run, placeId) end, "确认迁居", nil, { type = "migration" })
            end, {
                height = 76, disabled = current or not affordable, role = "secondary", textAlign = "left",
                paddingHorizontal = 12, fontSize = 12,
            }))
        end
    end
    local assetActions = {}
    local assets = {
        { id = "land", label = "购田", outcome = "田地 +1 亩；年度结算多收 4 石粮。" },
        { id = "workshop", label = "置办作坊", outcome = "有在世手艺人经营时，年度结算增加 8 两。" },
        { id = "shop", label = "置办商铺", outcome = "有在世经商者经营时，年度结算增加 10 两。" },
    }
    for _, asset in ipairs(assets) do
        local item = asset
        local quote = assert(Simulation.AssetQuote(self.run, item.id))
        local owned = (item.id == "workshop" and self.run.workshop) or (item.id == "shop" and self.run.shop)
        local affordable = self.run.money >= quote.price
        local label = owned and (item.label .. " · 已置办") or (item.label .. " · " .. tostring(quote.price) .. " 两")
        table.insert(assetActions, Button(label, function()
            local current = assert(Simulation.AssetQuote(self.run, item.id))
            local discount = current.discount > 0 and "（已减免" .. tostring(current.discount) .. "两）" or ""
            self:ConfirmRunAction("确认" .. item.label, "成本：" .. tostring(current.price) .. " 两" .. discount .. "。\n结果：" .. item.outcome, function(run) return Simulation.BuyAsset(run, item.id) end, "确认置办")
        end, { height = 46, fontSize = 13, disabled = owned or not affordable, role = "secondary" }))
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
        UI.Panel { height = 118, backgroundImage = V7.HomeImage(self.run.homeId, V7.HouseState(self.run)), backgroundFit = "cover", borderWidth = 1, borderColor = C.gold },
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
                self:RunAction(function() return Simulation.BuyGrain(self.run, grainQuote.amount) end)
            end, { height = 46, fontSize = 14, disabled = self.run.money < grainQuote.price, role = "secondary" }))
        end
        table.insert(estateChildren, Label("置办家业", { fontSize = 17, fontWeight = "bold", marginTop = 5 }))
        table.insert(estateChildren, UI.SimpleGrid { minColumnWidth = 155, gap = 7, children = assetActions })
        local aid = Data.EventChoice("community_request", "aid")
        local aidCost = aid and aid.cost or 15
        table.insert(estateChildren, Button("接济邻里（" .. tostring(aidCost) .. " 两）", function() self:ConfirmRunAction("确认接济邻里", "成本：" .. tostring(aidCost) .. " 两。\n结果：接济次数与声望写入家史。", function() return Simulation.AidCommunity(self.run) end, "确认接济") end, { height = 46, disabled = self.run.money < aidCost, role = "secondary" }))
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
    return RelicsView.Build(self)
end

function App:BuildAnnualFooter()
    if self.run.ending then return nil end
    local pending = Simulation.PendingEvents(self.run)
    local submitted = false
    return UI.Panel { flexShrink = 0, padding = 8, gap = 4, backgroundColor = C.card, borderTopWidth = 1, borderTopColor = C.line, children = {
        Label(#pending > 0 and "先做完眼前的决定，再继续这一年" or "本年安排会持续，不必重复设置", { fontSize = 12, fontColor = C.muted }),
        Button(#pending > 0 and "处理家事  →" or "推进这一年  →", function()
            if #pending > 0 then self.gameTab = "family"; self:Render()
            elseif not submitted then
                submitted = true
                if not self:RunAction(function() return Simulation.AdvanceYear(self.run, self.profile) end) then submitted = false end
            end
        end, { width = "100%", height = 48, fontSize = 16, role = #pending > 0 and "secondary" or "primary" }),
    } }
end

function App:BuildHistoryTab()
    return HistoryView.Build(self)
end

function App:BuildGame()
    local builders = { family = function() return self:BuildFamilyTab() end, people = function() return self:BuildPeopleTab() end, estate = function() return self:BuildEstateTab() end, relics = function() return self:BuildRelicsTab() end, history = function() return self:BuildHistoryTab() end }
    local openingSnapshot = TableValue(self.run.openingSnapshot)
    local familyName = tostring(openingSnapshot["family"] or "无名") .. "氏"
    local children = {
        Visual.Decor("mountains", { position = "absolute", bottom = 140, left = 0, width = "100%", height = 250, opacity = 0.12, pointerEvents = "none" }),
        Visual.Decor("tree", { position = "absolute", top = 100, right = 0, width = 120, height = 210, opacity = 0.12, pointerEvents = "none" }),
        self:BuildHeader(familyName, "第 " .. tostring(self.run.yearIndex + 1) .. " 年"),
        self:BuildRunStatusBar(),
        UI.ScrollView { flexGrow = 1, flexBasis = 0, padding = 12, backgroundColor = { 0, 0, 0, 0 }, children = { builders[self.gameTab]() } },
    }
    local annualFooter = self:BuildAnnualFooter()
    if annualFooter then table.insert(children, annualFooter) end
    table.insert(children, self:BuildGameNav())
    return UI.Panel { width = "100%", height = "100%", backgroundColor = C.paper, backgroundImage = V7.Images.paperTexture, backgroundImageOpacity = 1, backgroundFit = "cover", flexDirection = "column", children = children }
end

function App:Render()
    local source = self.screen == "opening" and (self.openingEditDraft or self.draft) or self.run or self.draft
    Visual.SetArtVersion(source and source.artVersion)
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
        height = "100%",
        backgroundColor = C.paper,
        backgroundImage = V7.Images.paperTexture,
        backgroundImageOpacity = 1,
        backgroundFit = "cover",
        overflow = "hidden",
        flexDirection = "column",
        children = children,
    }
    self.root = UI.SafeAreaView {
        width = "100%",
        height = "100%",
        edges = "vertical",
        nativeMenuInset = true,
        backgroundColor = C.dark,
        alignItems = "center",
        children = { phoneFrame },
    }
    UI.SetRoot(self.root, true)
end

OpeningEditor.Apply(App)

return App
