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

local BATCH_ROUTES = {
    { id = "study", title = "修身研习", icon = "info", detail = "读书、学艺、学医与习武，为日后开路。", jobIds = { "study", "apprentice", "medical", "train" } },
    { id = "livelihood", title = "经营生计", icon = "estate", detail = "以劳作、本领与商路支撑全家。", jobIds = { "farm", "craft", "trade", "teach", "doctor", "guard" } },
    { id = "family", title = "照料家室", icon = "relationship", detail = "料理家事、休养，或让孩子随家人生活。", jobIds = { "home", "rest", "play" } },
    { id = "leadership", title = "承担族务", icon = "leader", detail = "通过应试后，可承担地方职务。", jobIds = { "official" } },
}

local function BatchRouteById(routeId)
    for _, route in ipairs(BATCH_ROUTES) do if route.id == routeId then return route end end
    return nil
end

local function Signed(value)
    return ((value or 0) >= 0 and "+" or "") .. tostring(value or 0)
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
    self.peopleSelected = {}
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
            self.draft = draft
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
    self.familyGeneration = 0; self.peopleSelected = {}
    self.openingEditDraft = nil; self.memberEditing = nil; self.memberLifePages = {}; self.historyPages = {}
    self.previousDraft = nil; self.editBackup = nil; self.houseUndo = nil; self.openingView = "summary"; self.undo = {}; self.historyPage = 1; self.historySection = "annals"; self.storageBlocked = false; self.openingGenerationFailed = false
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
        Button("立新家谱", function() modal:Close(); self:PrepareNewRun() end, { width = "100%", role = "secondary" }),
    } }))
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
        self.familyGeneration = 0; self.peopleSelected = {}
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
    local living = 0
    for _, member in ipairs(self.run.members) do
        if member.alive then living = living + 1 end
    end
    return living, Economy.StandardAnnualFoodNeed(self.run)
end

function App:BuildRunStatusBar()
    local forecast = assert(Economy.AnnualForecast(self.run))
    local forecastStatusText = "余粮 " .. tostring(forecast.projectedGrain) .. " 石"
    local forecastColor = C.green
    if forecast.foodShortfall > 0 then
        if forecast.foodSatisfied then
            forecastStatusText = "补购 " .. tostring(forecast.boughtGrain) .. " 石"
            forecastColor = C.gold
        else
            forecastStatusText = "缺粮 " .. tostring(forecast.foodShortfall) .. " 石"
            forecastColor = C.warning
        end
    end
    return UI.Panel {
        height = 58, flexShrink = 0,
        borderBottomWidth = 1, borderBottomColor = C.line,
        children = {
            UI.Row {
                height = 32, paddingHorizontal = 14, gap = 6, alignItems = "center",
                children = {
                    Visual.Icon("money", 16), Label(tostring(self.run.money) .. " 两", { fontSize = 15 }),
                    Visual.Icon("grain", 16), Label(tostring(self.run.grain) .. " 石", { fontSize = 15 }),
                    UI.Panel { flex = 1 },
                    Label(Data.WORLD_NAME .. "历 " .. tostring(self.run.calendar) .. " 年", { fontSize = 12, fontColor = C.muted }),
                },
            },
            UI.Row {
                height = 25, paddingHorizontal = 14, gap = 5, alignItems = "center", backgroundColor = C.card,
                borderTopWidth = 1, borderTopColor = C.line,
                children = {
                    Label("下年预计", { fontSize = 12, fontColor = C.muted }),
                    Visual.Icon("money", 13, "muted"),
                    Label("−" .. tostring(forecast.livingExpense) .. " 两", { fontSize = 13, fontColor = C.muted }),
                    Visual.Icon("grain", 13, "muted"),
                    Label("−" .. tostring(forecast.foodNeed) .. " 石", { fontSize = 13, fontColor = C.muted }),
                    UI.Panel { flex = 1 },
                    Label(forecastStatusText, { fontSize = 12, fontColor = forecastColor }),
                },
            },
        },
    }
end

function App:BuildCover()
    local actions = {
        UI.Panel { gap = 3, children = {
            UI.Row { gap = 8, alignItems = "center", children = {
                Visual.Decor("seal_square", { width = 28, height = 28 }),
                Label("凡世王朝 · " .. Data.WORLD_NAME, { fontSize = 13, fontColor = C.green }),
            } },
            Label("家业", { fontSize = 46, fontWeight = "bold", fontFamily = "serif", letterSpacing = 8, textShadow = { offsetX = 1, offsetY = 2, blur = 2, color = { 255, 249, 235, 180 } } }),
            Label("一户人的家谱，代代相传", { fontSize = 19, fontColor = C.green, fontFamily = "serif", letterSpacing = 2 }),
        } },
        UI.Panel { gap = 8, padding = 15, backgroundColor = { 247, 240, 223, 235 }, borderWidth = 1, borderColor = C.gold, borderRadius = 8, boxShadow = { { x = 0, y = 3, blur = 10, color = { 20, 43, 33, 45 } } }, children = {
            Label("从一页家书开始", { fontSize = 19, fontColor = C.ink, fontFamily = "serif" }),
            Label("生成一户人家，逐项改写家人、家底与首年安排。每一次抉择都会留在家谱里。", { fontSize = 15, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.65 }),
            UI.Row { gap = 6, children = {
                Label("家人", { flex = 1, fontSize = 13, fontColor = C.green, textAlign = "center" }),
                Label("家业", { flex = 1, fontSize = 13, fontColor = C.green, textAlign = "center" }),
                Label("家史", { flex = 1, fontSize = 13, fontColor = C.green, textAlign = "center" }),
            } },
        } },
    }
    if self.openingGenerationFailed then
        table.insert(actions, Label(self.openingFeedback, { fontSize = 14, fontColor = C.warning, whiteSpace = "normal", lineHeight = 1.5 }))
    end
    table.insert(actions, Button(self.run and "另立家谱" or "展开家谱", function() self:PrepareNewRun() end, { height = 54, fontSize = 17, marginTop = 4 }))
    if self.run then
        table.insert(actions, Button("续写当前家谱", function() self:Load() end, { height = 46, role = "secondary" }))
    end
    return UI.Panel { width = "100%", height = "100%", overflow = "hidden", children = {
        Visual.OpeningArt("landscape", { position = "absolute", left = 0, top = 0, width = "100%", height = "100%", backgroundFit = "cover" }),
        UI.Panel { position = "absolute", left = 0, top = 0, width = "100%", height = "100%", backgroundGradient = {
            type = "linear", direction = "to-bottom", from = { 247, 240, 223, 45 }, to = { 247, 240, 223, 222 },
        }, pointerEvents = "none" },
        Visual.OpeningArt("tableau", { position = "absolute", left = 0, bottom = -38, width = "100%", height = 340, backgroundFit = "contain", opacity = 0.94 }),
        UI.SafeAreaView { width = "100%", height = "100%", edges = "all", children = {
            UI.Panel { width = "100%", height = "100%", padding = 22, justifyContent = "space-between", pointerEvents = "box-none", children = {
                UI.Panel { pointerEvents = "none", children = {
                    Label("家谱从此落笔", { fontSize = 13, fontColor = C.muted, textAlign = "right" }),
                } },
                UI.Panel { gap = 14, pointerEvents = "box-none", children = actions },
            } },
        } },
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
            children = { Visual.Icon(tab.icon, 23, active and "ink" or "muted"), Label(tab.text, { fontSize = 13, fontColor = active and C.green or C.muted }) },
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

function App:SelectedLivingMembers()
    local members = {}
    for _, member in ipairs(self.run.members) do
        if member.alive and self.peopleSelected[member.id] then table.insert(members, member) end
    end
    return members
end

function App:TogglePeopleSelection(memberId)
    self.peopleSelected[memberId] = not self.peopleSelected[memberId]
    self:Render()
end

function App:SelectAllLivingPeople()
    self.peopleSelected = {}
    for _, member in ipairs(self.run.members) do if member.alive then self.peopleSelected[member.id] = true end end
    self:Render()
end

function App:ClearPeopleSelection()
    self.peopleSelected = {}
    self:Render()
end

function App:ConfirmBatchJob(memberIds, jobId, parentModal)
    local plan, forecast = Simulation.PreviewBatchJob(self.run, memberIds, jobId)
    if not plan then self:Notify(forecast, "warning"); return end
    if #plan.targets == 0 then self:Notify("所选族人当前没有可写入的新安排。", "warning"); return end
    local job = Data.Jobs[jobId]
    local targetNames, unchangedNames, blockedNames = {}, {}, {}
    for _, member in ipairs(plan.targets) do table.insert(targetNames, member.name) end
    for _, member in ipairs(plan.unchanged) do table.insert(unchangedNames, member.name) end
    for _, item in ipairs(plan.blocked) do table.insert(blockedNames, item.name .. "（" .. item.reason .. "）") end
    local lines = {
        "将安排 " .. table.concat(targetNames, "、") .. " 从事“" .. job.name .. "”。",
        "本年全家预计：银 " .. Signed(forecast.netMoney) .. " 两 · 粮 " .. Signed(forecast.netGrain) .. " 石。",
    }
    if #unchangedNames > 0 then table.insert(lines, "已在此安排：" .. table.concat(unchangedNames, "、") .. "。") end
    if #blockedNames > 0 then table.insert(lines, "保留当前安排：" .. table.concat(blockedNames, "、") .. "。") end
    self:ConfirmRunAction("批量安排 · " .. job.name, table.concat(lines, "\n\n"), function()
        local ok, message = Simulation.SetJobs(self.run, memberIds, jobId)
        if ok then self.peopleSelected = {} end
        return ok, message
    end, "确认安排 " .. tostring(#plan.targets) .. " 人", parentModal)
end

function App:OpenBatchJobPlanner(routeId)
    local members = self:SelectedLivingMembers()
    if #members == 0 then self:Notify("先勾选要安排的在世族人。", "warning"); return end
    local memberIds, memberNames = {}, {}
    for _, member in ipairs(members) do
        table.insert(memberIds, member.id)
        table.insert(memberNames, member.name)
    end
    local route = routeId and BatchRouteById(routeId) or nil
    if routeId and not route then self:Notify("安排类别不存在。", "warning"); return end
    local modal = nil
    local body = UI.Panel { gap = 10 }
    body:AddChild(Card({
        Label("已选 " .. tostring(#members) .. " 人", { fontSize = 18, fontWeight = "bold" }),
        Label(table.concat(memberNames, "、"), { fontSize = 14, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
        Label("选择同一项去向后，页面会提前说明可写入人数与保留原安排的人数。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
    }, { backgroundColor = C.pale, borderColor = C.green }))
    if not route then
        body:AddChild(SectionTitle("选择安排类别", "4 类"))
        for _, option in ipairs(BATCH_ROUTES) do
            local optionId = option.id
            local availableJobs = 0
            for _, jobId in ipairs(option.jobIds) do
                local plan = Simulation.PreviewBatchJob(self.run, memberIds, jobId)
                if plan and #plan.targets > 0 then availableJobs = availableJobs + 1 end
            end
            body:AddChild(Card({ UI.Row { gap = 10, alignItems = "center", children = {
                Visual.Icon(option.icon, 24, "muted"),
                UI.Panel { flex = 1, minWidth = 0, gap = 3, children = {
                    Label(option.title, { fontSize = 18, fontWeight = "bold" }),
                    Label(option.detail, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
                    Label(availableJobs > 0 and ("可选 " .. tostring(availableJobs) .. " 项去向") or "当前没有符合条件的去向", { fontSize = 13, fontColor = availableJobs > 0 and C.green or C.warning }),
                } },
                Visual.Icon("forward", 18, "muted"),
            } } }, {
                borderColor = availableJobs > 0 and C.gold or C.line,
                pointerEvents = "box-only",
                onClick = function()
                    modal:Close()
                    self:OpenBatchJobPlanner(optionId)
                end,
            }))
        end
    else
        body:AddChild(Button("换一类安排", function()
            modal:Close()
            self:OpenBatchJobPlanner()
        end, { width = "100%", role = "secondary" }))
        body:AddChild(SectionTitle(route.title, "选择具体去向"))
        for _, jobId in ipairs(route.jobIds) do
            local selectedJobId = jobId
            local job = Data.Jobs[jobId]
            local plan, forecast = Simulation.PreviewBatchJob(self.run, memberIds, jobId)
            local targets = plan and #plan.targets or 0
            local unchanged = plan and #plan.unchanged or 0
            local blocked = plan and #plan.blocked or 0
            local status = targets > 0 and ("可安排 " .. tostring(targets) .. " 人") or "当前无人符合条件"
            local note = targets > 0 and ("安排后本年全家预计：银 " .. Signed(forecast.netMoney) .. " 两 · 粮 " .. Signed(forecast.netGrain) .. " 石") or "保留当前安排，详情可在个人安排中查看。"
            local counts = {}
            if unchanged > 0 then table.insert(counts, "已有 " .. tostring(unchanged) .. " 人") end
            if blocked > 0 then table.insert(counts, "保留 " .. tostring(blocked) .. " 人") end
            body:AddChild(Card({ UI.Row { gap = 10, alignItems = "flex-start", children = {
                UI.Panel { flex = 1, minWidth = 0, gap = 4, children = {
                    Label(job.name, { fontSize = 18, fontWeight = "bold" }),
                    Label(job.desc, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
                    Label(note, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
                    #counts > 0 and Label(table.concat(counts, " · "), { fontSize = 13, fontColor = C.warning, whiteSpace = "normal" }) or UI.Panel { height = 0 },
                } },
                UI.Panel { gap = 4, alignItems = "flex-end", children = {
                    Label(status, { fontSize = 14, fontColor = targets > 0 and C.green or C.warning }),
                    targets > 0 and Visual.Icon("forward", 18, "muted") or UI.Panel { width = 18, height = 18 },
                } },
            } } }, {
                borderColor = targets > 0 and C.gold or C.line,
                pointerEvents = targets > 0 and "box-only" or "auto",
                onClick = targets > 0 and function() self:ConfirmBatchJob(memberIds, selectedJobId, modal) end or nil,
            }))
        end
    end
    modal = ModalLayout.New("批量安排 · " .. tostring(#members) .. " 人", {
        sheet = route and "full" or "detail", backgroundColor = C.card, borderColor = C.line,
        closeOnOverlay = true,
        onClose = function(selfModal) selfModal:Destroy() end,
    })
    modal:AddContent(ModalLayout.Scroll(body))
    modal:SetFooter(Button("返回族人", function() modal:Close() end, { width = "100%", role = "secondary", height = 46 }))
    modal:Open()
end

function App:BuildPeopleTab()
    local pendingByMember = {}
    for _, event in ipairs(Simulation.PendingEvents(self.run)) do
        for _, memberId in ipairs({ event.memberId, event.executorId }) do
            if memberId then pendingByMember[memberId] = (pendingByMember[memberId] or 0) + 1 end
        end
    end
    local living, deceased = {}, 0
    for _, member in ipairs(self.run.members) do
        if member.alive then table.insert(living, member) else deceased = deceased + 1 end
    end
    local selected = self:SelectedLivingMembers()
    local cards = { Card({
        Label("本年安排", { fontSize = 21, fontWeight = "bold" }),
        Label("勾选在世族人后，可一次安排同一种去向；每个人的经历、亲缘与资格仍会分别保留。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.45 }),
        Label("在世 " .. tostring(#living) .. " 人 · 已选 " .. tostring(#selected) .. " 人", { fontSize = 15, fontColor = C.green, fontWeight = "bold" }),
        UI.Row { gap = 8, children = {
            Button("全选在世", function() self:SelectAllLivingPeople() end, { flex = 1, role = "secondary" }),
            Button("清空选择", function() self:ClearPeopleSelection() end, { flex = 1, role = "secondary" }),
        } },
        #selected > 0 and Button("为 " .. tostring(#selected) .. " 人安排本年去向", function() self:OpenBatchJobPlanner() end, { width = "100%" }) or Label("勾选后可直接进入批量安排。", { fontSize = 13, fontColor = C.muted }),
    }, { borderColor = C.gold }) }
    table.insert(cards, SectionTitle("在世族人", tostring(#living) .. " 人"))
    for _, member in ipairs(living) do
        local isSelected = self.peopleSelected[member.id] == true
        local state = member.id == self.run.leaderId and "族长" or "在世"
        local pendingText = pendingByMember[member.id] and (" · 待办 " .. tostring(pendingByMember[member.id])) or ""
        table.insert(cards, Card({
            UI.Row { gap = 12, alignItems = "center", children = {
                Visual.Portrait(member, { size = 60, leader = member.id == self.run.leaderId, selected = isSelected }),
                UI.Panel { flex = 1, minWidth = 0, gap = 4, children = {
                    Label(member.name, { fontSize = 21, fontWeight = "bold", whiteSpace = "normal" }),
                    Label(tostring(member.age) .. " 岁 · " .. state .. " · 第 " .. tostring(State.Generation(self.run.members, member.id)) .. " 代", { fontSize = 13, fontColor = C.muted }),
                    Label(Data.Jobs[member.jobId].name .. pendingText, { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }),
                } },
            } },
            Label(MemberRelationText(self.run, member), { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
            UI.Row { gap = 8, children = {
                Button("个人安排", function() self:OpenRunMember(member.id) end, { flex = 1, height = 44, role = "secondary" }),
                Button(isSelected and "已选" or "勾选", function() self:TogglePeopleSelection(member.id) end, { width = 76, height = 44, role = isSelected and "primary" or "secondary" }),
            } },
        }, {
            backgroundColor = isSelected and C.pale or C.card,
            borderColor = isSelected and C.green or C.line,
        }))
    end
    if #living == 0 then table.insert(cards, Card({ Label("当前没有在世族人", { fontSize = 17, fontWeight = "bold" }), Label("此局人物生平已完整留入家史。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }) })) end
    if deceased > 0 then table.insert(cards, Card({
        Label("已故族人 · " .. tostring(deceased) .. " 人", { fontSize = 17, fontWeight = "bold" }),
        Label("生平、亲缘与往年安排已收入家史。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }),
        Button("查看家史", function() self.gameTab = "history"; self.historySection = "annals"; self.historyPage = 1; self:Render() end, { width = "100%", role = "secondary" }),
    })) end
    return UI.Panel { gap = 10, children = cards }
end

function App:BuildEstateTab()
    local function EstateActionCard(spec)
        local statusColor = spec.statusColor or (spec.available and C.green or C.warning)
        local children = {
            UI.Row { gap = 10, alignItems = "flex-start", children = {
                UI.Panel { flex = 1, minWidth = 0, gap = 3, children = {
                    Label(spec.title, { fontSize = 17, fontWeight = "bold", whiteSpace = "normal" }),
                    Label(spec.outcome, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
                } },
                UI.Panel { minWidth = 76, gap = 2, alignItems = "flex-end", children = {
                    Label(spec.costCaption or "花费", { fontSize = 11, fontColor = C.muted }),
                    UI.Row { gap = 4, alignItems = "center", children = {
                        Visual.Icon("money", 14, "muted"),
                        Label(spec.costText, { fontSize = 16, fontWeight = "bold", fontColor = C.warning }),
                    } },
                } },
            } },
        }
        if spec.detail then table.insert(children, Label(spec.detail, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 })) end
        table.insert(children, UI.Row { gap = 8, alignItems = "center", children = {
            Label(spec.timing, { flex = 1, fontSize = 12, fontColor = C.muted, whiteSpace = "normal" }),
            Label(spec.status, { fontSize = 13, fontColor = statusColor }),
            spec.available and Visual.Icon("forward", 17, "muted") or UI.Panel { width = 17, height = 17 },
        } })
        return Card(children, {
            minHeight = spec.minHeight or 96, padding = 11, gap = 6,
            backgroundColor = spec.backgroundColor or C.card,
            borderColor = spec.borderColor or (spec.available and C.gold or C.rule),
            pointerEvents = spec.available and spec.onClick and "box-only" or "auto",
            onClick = spec.available and spec.onClick or nil,
        })
    end

    local placeButtons = {}
    if not self.run.ending then
        for _, place in ipairs(Data.Places) do
            local placeId = place.id
            local current = self.run.placeId == placeId
            local quote = current and { cost = 0 } or assert(Simulation.MigrationQuote(self.run, placeId))
            local affordable = self.run.money >= quote.cost
            if current then
                table.insert(placeButtons, Card({
                    UI.Row { gap = 10, alignItems = "center", children = {
                        UI.Panel { flex = 1, gap = 3, children = {
                            Label("当前居所 · " .. place.short, { fontSize = 17, fontWeight = "bold" }),
                            Label(place.desc .. "\n" .. place.burden, { fontSize = 13, fontColor = C.muted, whiteSpace = "normal", lineHeight = 1.4 }),
                        } },
                        Label("已落脚", { fontSize = 13, fontColor = C.green }),
                    } },
                    Label("无需安置费", { fontSize = 12, fontColor = C.muted }),
                }, { minHeight = 84, padding = 11, gap = 6, backgroundColor = C.pale, borderColor = C.gold }))
            else
                table.insert(placeButtons, EstateActionCard({
                    title = "迁居 " .. place.short,
                    costCaption = "安置费",
                    costText = tostring(quote.cost) .. " 两",
                    outcome = place.desc,
                    detail = place.burden,
                    timing = "迁居后立即生效，并写入家史",
                    available = affordable,
                    status = affordable and "可迁居" or "尚差 " .. tostring(quote.cost - self.run.money) .. " 两",
                    onClick = function()
                        local currentQuote, reason = Simulation.MigrationQuote(self.run, placeId)
                        if not currentQuote then self:Notify(reason, "warning"); return end
                        local benefit = currentQuote.discount > 0 and ("\n通家玉佩抵扣 " .. tostring(currentQuote.discount) .. " 两，本次实迁后进入冷却。") or ""
                        self:ConfirmRunAction("确认迁居 · " .. place.short, "成本：" .. tostring(currentQuote.cost) .. " 两安置费。" .. benefit .. "\n结果：全家迁居到" .. place.short .. "，迁居年份与费用写入家史。", function() return Simulation.MoveFamily(self.run, placeId) end, "确认迁居", nil, { type = "migration" })
                    end,
                }))
            end
        end
    end
    ---@type string[]
    local craftNames = {}
    ---@type string[]
    local tradeNames = {}
    for _, member in ipairs(self.run.members) do
        if member.alive and member.jobId == "craft" then table.insert(craftNames, member.name) end
        if member.alive and member.jobId == "trade" then table.insert(tradeNames, member.name) end
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
        if not owned then
            local operator = item.id == "workshop" and (#craftNames > 0 and ("经营人：" .. table.concat(craftNames, "、")) or "需安排在世族人手艺谋生，才会结算收益。")
                or item.id == "shop" and (#tradeNames > 0 and ("经营人：" .. table.concat(tradeNames, "、")) or "需安排在世族人外出经商，才会结算收益。")
                or "本年置办，下年结算起多收粮食。"
            local discount = quote.discount > 0 and ("原价 " .. tostring(quote.basePrice) .. " 两，已减免 " .. tostring(quote.discount) .. " 两。") or operator
            table.insert(assetActions, EstateActionCard({
                title = item.label,
                costText = tostring(quote.price) .. " 两",
                outcome = item.outcome,
                detail = discount,
                timing = "置办后立即生效",
                available = affordable,
                status = affordable and "可置办" or "尚差 " .. tostring(quote.price - self.run.money) .. " 两",
                onClick = function()
                    local current = assert(Simulation.AssetQuote(self.run, item.id))
                    local currentDiscount = current.discount > 0 and "（已减免" .. tostring(current.discount) .. "两）" or ""
                    self:ConfirmRunAction("确认" .. item.label, "成本：" .. tostring(current.price) .. " 两" .. currentDiscount .. "。\n结果：" .. item.outcome, function(run) return Simulation.BuyAsset(run, item.id) end, "确认置办")
                end,
            }))
        end
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
            table.insert(estateChildren, EstateActionCard({
                title = "购入 " .. tostring(grainQuote.amount) .. " 石粮",
                costText = tostring(grainQuote.price) .. " 两",
                outcome = "存粮 +" .. tostring(grainQuote.amount) .. " 石，立即入库。",
                detail = "年度缺粮时的自动补购，也按当前落脚处的同一价格结算。",
                timing = "购入后立即生效",
                available = self.run.money >= grainQuote.price,
                status = self.run.money >= grainQuote.price and "可购入" or "尚差 " .. tostring(grainQuote.price - self.run.money) .. " 两",
                onClick = function() self:RunAction(function() return Simulation.BuyGrain(self.run, grainQuote.amount) end) end,
            }))
        end
        table.insert(estateChildren, Label("置办家业", { fontSize = 17, fontWeight = "bold", marginTop = 5 }))
        table.insert(estateChildren, #assetActions > 0 and UI.Panel { gap = 7, children = assetActions }
            or Label("田地、作坊和商铺均已置办，可继续安排经营人。", { fontSize = 14, fontColor = C.muted, whiteSpace = "normal" }))
        local aid = Data.EventChoice("community_request", "aid")
        local aidCost = aid and aid.cost or 15
        table.insert(estateChildren, EstateActionCard({
            title = "接济邻里",
            costText = tostring(aidCost) .. " 两",
            outcome = "接济次数与声望写入家史。",
            detail = "用于回应乡里的求助，并保留为本局事实。",
            timing = "确认后立即生效",
            available = self.run.money >= aidCost,
            status = self.run.money >= aidCost and "可接济" or "尚差 " .. tostring(aidCost - self.run.money) .. " 两",
            onClick = function() self:ConfirmRunAction("确认接济邻里", "成本：" .. tostring(aidCost) .. " 两。\n结果：接济次数与声望写入家史。", function() return Simulation.AidCommunity(self.run) end, "确认接济") end,
        }))
    end
    local estateCard = Card(estateChildren)
    local moveCard = Card({
        Label("迁居", { fontSize = 18, fontWeight = "bold" }),
        Label("迁居会写入真实年份和费用，不会把家人折叠成不可操作支系。", { fontSize = 13, fontColor = C.muted, whiteSpace = "normal" }),
        self.run.ending and Label("迁居记录已封存，可在家史中回看。", { fontSize = 14, fontColor = C.muted }) or UI.Panel { gap = 7, children = placeButtons },
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
