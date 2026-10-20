local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Opening = require "Jiaye.Opening"
local RelicDefinitions = require "Jiaye.RelicDefinitions"
local RelicState = require "Jiaye.RelicState"
local V7 = require "Jiaye.V7"

---@class OpeningEditorController
---@field profile table
---@field draft table
---@field run table|nil
---@field openingEditDraft table|nil
---@field openingView string
---@field openingPage string
---@field openingFeedback string
---@field openingReturn string|nil
---@field undo table
---@field houseUndo table|nil
---@field editBackup table|nil
---@field editUndo table|nil
---@field editHouseUndo table|nil
---@field nameEditing string|nil
---@field memberEditing table|nil
---@field memberIsNew boolean|nil
---@field memberRemoving boolean|nil
---@field memberLeader number|nil
---@field memberReturn string|nil
---@field memberSection string|nil
---@field memberIssue string
---@field removeConfirm boolean
---@field Save fun(self: OpeningEditorController): boolean
---@type table
local OpeningEditor = {}

local function render(app)
    app:Render()
end

local function editDraft(app)
    return app.openingEditDraft or app.draft
end

local function backgroundForOrigin(originId)
    for _, background in ipairs(Data.Backgrounds or {}) do
        if background.originId == originId then return background end
    end
    return nil
end

local function prepareNewDraftFields(draft)
    if draft.rulesVersion == nil then draft.rulesVersion = Data.RULES_VERSION end
    if draft.habitId == nil then draft.habitId = "none" end
    if draft.tieId == nil then draft.tieId = "none" end
    if Opening.IsNewRelicDraft(draft) then
        draft.selectedRelicFormIds = type(draft.selectedRelicFormIds) == "table" and draft.selectedRelicFormIds or {}
        draft.relicUsers = type(draft.relicUsers) == "table" and draft.relicUsers or {}
        Opening.EnsureRelicUsers(draft)
    end
    local background = backgroundForOrigin(draft.originId)
    draft.backgroundId = background and background.id or nil
    for _, member in ipairs(draft.members or {}) do
        if member.focus == nil then member.focus = "general" end
    end
end

---@param app OpeningEditorController
function OpeningEditor.Init(app)
    if not app.run then prepareNewDraftFields(app.draft) end
    app.openingPage = app.openingPage or "world"
    app.openingView = app.openingView or "summary"
    app.openingFeedback = app.openingFeedback or ""
    app.undo = app.undo or {}
    app.openingEditDraft = nil
    app.editBackup = nil
    app.editUndo = nil
    app.editHouseUndo = nil
    app.houseUndo = nil
    app.memberEditing = nil
    app.memberIsNew = nil
    app.memberRemoving = nil
    app.memberIssue = ""
end

---@param self OpeningEditorController
function OpeningEditor.SetDraftField(self, page, key, value)
    local draft = editDraft(self)
    draft[key] = State.Copy(value)
    if page == "relics" and Opening.IsNewRelicDraft(draft) then
        Opening.EnsureRelicUsers(draft, self.profile)
    end
    if page == "world" and key == "originId" then
        local background = backgroundForOrigin(draft.originId)
        draft.backgroundId = background and background.id or nil
    end
    self.undo[page] = nil
    self.houseUndo = nil
    self.openingFeedback = ""
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.MarkOpeningPageChanged(self, page)
    self.undo[page] = nil
    self.houseUndo = nil
    self.openingFeedback = ""
end

---@param self OpeningEditorController
function OpeningEditor.RandomFamilyName(self)
    local wasEditing = self.openingEditDraft ~= nil
    local candidate = State.Copy(editDraft(self))
    local ok, message = Opening.RandomFamilyName(candidate)
    if ok then
        prepareNewDraftFields(candidate)
        if wasEditing then
            self.openingEditDraft = candidate
            self.nameEditing = candidate.family
        else
            self.draft = candidate
        end
        self.undo.people = nil
        self.houseUndo = nil
    end
    self.openingFeedback = message
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.RandomizePage(self, page)
    local wasEditing = self.openingEditDraft ~= nil
    local source = State.Copy(editDraft(self))
    local before = Opening.Snapshot(source, page)
    local candidate, issue = Opening.RandomPage(source, page, self.profile)
    if candidate then
        prepareNewDraftFields(candidate)
        if wasEditing then self.openingEditDraft = candidate else self.draft = candidate end
        self.undo[page] = { before = before, after = Opening.Snapshot(candidate, page) }
        self.houseUndo = nil
        self.openingFeedback = "已随机当前对象，可撤销；其他对象保持不变。"
    else
        self.openingFeedback = issue
    end
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.UndoPage(self, page)
    local draft = editDraft(self)
    local undo = self.undo[page]
    if not undo or not Opening.Equal(Opening.Snapshot(draft, page), undo.after) then
        self.undo[page] = nil
        self.openingFeedback = "当前对象已经改过，或没有可撤销结果。"
    else
        local candidate = State.Copy(draft)
        Opening.Restore(candidate, page, undo.before)
        local issues = State.ValidateDraft(candidate, self.profile, true)
        if #issues > 0 then
            self.openingFeedback = table.concat(issues, "\n")
            render(self)
            return
        end
        if self.openingEditDraft then self.openingEditDraft = candidate else self.draft = candidate end
        self.undo[page] = nil
        self.openingFeedback = "已撤销当前对象的随机结果。"
    end
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.ChangeHouse(self)
    local candidate, issue = Opening.Generate(self.profile, Opening.FreshSeed(), "mortal")
    if candidate then
        self.houseUndo = State.Copy(self.draft)
        self.draft = candidate
        self.openingEditDraft = nil
        self.editBackup = nil
        self.editUndo = nil
        self.editHouseUndo = nil
        self.undo = {}
        self.openingFeedback = "已换一家；可以恢复上一家。"
    else
        self.openingFeedback = issue
    end
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.UndoHouse(self)
    if not self.houseUndo then return end
    self.draft = self.houseUndo
    self.houseUndo = nil
    self.openingEditDraft = nil
    self.editBackup = nil
    self.editUndo = nil
    self.editHouseUndo = nil
    self.undo = {}
    self.openingFeedback = "已恢复上一家。"
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.BeginOpeningEdit(self, page)
    if not self.openingEditDraft then
        self.openingEditDraft = State.Copy(self.draft)
        self.editBackup = State.Copy(self.draft)
        self.editUndo = State.Copy(self.undo)
        self.editHouseUndo = State.Copy(self.houseUndo)
        prepareNewDraftFields(self.openingEditDraft)
    end
    self.openingPage = page or "world"
    self.nameEditing = self.openingEditDraft.family
    self.openingFeedback = ""
    self.openingView = page == "name" and "name" or "editor"
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.OpenOpeningDetail(self, view)
    self.openingReturn = self.openingView or "summary"
    self.openingView = view
    self.openingFeedback = ""
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.ReturnOpeningDetail(self)
    self.openingView = self.openingReturn or "summary"
    self.openingReturn = nil
    self.openingFeedback = ""
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.FinishOpeningEdit(self, save)
    if save then
        local candidate = State.Copy(self.openingEditDraft or self.draft)
        prepareNewDraftFields(candidate)
        local issues = State.ValidateDraft(candidate, self.profile, true)
        if #issues > 0 then
            self.openingFeedback = table.concat(issues, "\n")
            render(self)
            return false
        end
        self.draft = candidate
    else
        self.undo = self.editUndo or self.undo
        self.houseUndo = self.editHouseUndo
    end
    self.openingEditDraft = nil
    self.editBackup = nil
    self.editUndo = nil
    self.editHouseUndo = nil
    if save then self.houseUndo = nil end
    self.openingView = "summary"
    self.openingFeedback = ""
    render(self)
    return true
end

---@param self OpeningEditorController
function OpeningEditor.SaveOpeningDraft(self)
    if self.openingEditDraft and not OpeningEditor.FinishOpeningEdit(self, true) then return false end
    return self:Save()
end

---@param self OpeningEditorController
function OpeningEditor.SetOpeningPage(self, page)
    self.openingPage = page
    self.openingFeedback = ""
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.SelectPeriod(self, id)
    local draft = editDraft(self)
    draft.calendar = Data.Period(id).years[1]
    OpeningEditor.SetDraftField(self, "world", "periodId", id)
end

---@param self OpeningEditorController
function OpeningEditor.ToggleRelic(self, id)
    local draft = editDraft(self)
    if Opening.IsNewRelicDraft(draft) then
        local form = RelicDefinitions.Form(id)
        if not form then
            self.openingFeedback = "找不到该信物形态。"
            render(self)
            return
        end
        local selected = State.Copy(draft.selectedRelicFormIds or {})
        local found
        for index, value in ipairs(selected) do
            if value == id then
                table.remove(selected, index)
                found = true
                break
            end
        end
        if not found then
            for index = #selected, 1, -1 do
                local existing = RelicDefinitions.Form(selected[index])
                if existing and existing.familyId == form.familyId then table.remove(selected, index) end
            end
            table.insert(selected, id)
        end
        draft.selectedRelicFormIds = selected
        Opening.EnsureRelicUsers(draft, self.profile)
        if not found then draft.relicUsers[id] = RelicState.SuggestUser(draft.members, id) end
        self.undo.relics = nil
        self.houseUndo = nil
        self.openingFeedback = found and "已移出本局。" or "已选入该形态；同一成长线只保留一件。"
        render(self)
        return
    end
    local selected = State.Copy(draft.selectedRelicIds or {})
    local found = false
    for index, value in ipairs(selected) do
        if value == id then
            table.remove(selected, index)
            found = true
            break
        end
    end
    if not found then table.insert(selected, id) end
    OpeningEditor.SetDraftField(self, "relics", "selectedRelicIds", selected)
end

---@param self OpeningEditorController
function OpeningEditor.SetRelicUser(self, formId, memberId)
    local draft = editDraft(self)
    local ok, message = Opening.SetRelicUser(draft, formId, memberId)
    self.openingFeedback = message
    if ok then
        self.undo.relics = nil
        self.houseUndo = nil
    end
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.AddMember(self)
    local draft = editDraft(self)
    local id = draft.nextId
    self.memberIsNew = true
    self.memberEditing = {
        id = id, name = draft.family .. "新", givenName = "新", nameSource = "family", sex = "女",
        age = 18, parents = {}, talent = 2, focus = "general", experienceId = "none", trait = "沉静", jobId = "farm",
    }
    V7.Art.Assign(self.memberEditing, draft.rngSeed or "draft")
    self.memberLeader = draft.leaderId
    self.memberReturn = self.openingView
    self.memberSection = "base"
    self.memberIssue = ""
    self.removeConfirm = false
    self.memberRemoving = false
    self.openingView = "member"
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.MarkDraftMemberForRemoval(self)
    if self.memberIsNew or not self.memberEditing then return end
    if #(editDraft(self).members or {}) <= 1 then
        self.memberIssue = "至少保留一位族人。"
        render(self)
        return
    end
    self.memberRemoving = true
    self.memberIssue = ""
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.OpenDraftMember(self, memberId)
    local member = State.FindMember(editDraft(self).members, memberId)
    if not member then return end
    self.memberEditing = State.Copy(member)
    self.memberIsNew = false
    self.memberLeader = editDraft(self).leaderId
    self.memberReturn = self.openingView
    self.memberSection = "base"
    self.memberIssue = ""
    self.removeConfirm = false
    self.memberRemoving = false
    self.openingView = "member"
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.DraftMemberCandidate(self)
    local draft = editDraft(self)
    local candidate, issue
    if not self.memberEditing then return nil, "没有正在编辑的成员。" end
    if self.memberRemoving then
        candidate = State.Copy(draft)
        local removed = self.memberEditing.id
        local found = false
        for index, member in ipairs(candidate.members) do
            if member.id == removed then
                table.remove(candidate.members, index)
                found = true
                break
            end
        end
        if not found then return nil, "找不到要移除的成员。" end
        for _, member in ipairs(candidate.members) do
            if member.spouseId == removed then member.spouseId = nil end
            local parents = {}
            for _, parentId in ipairs(member.parents or {}) do
                if parentId ~= removed then table.insert(parents, parentId) end
            end
            member.parents = parents
        end
        local issues = State.ValidateDraft(candidate, self.profile, true)
        if #issues > 0 then return nil, table.concat(issues, "\n") end
    elseif self.memberIsNew then
        candidate = State.Copy(draft)
        table.insert(candidate.members, State.Copy(self.memberEditing))
        candidate.nextId = math.max(candidate.nextId or 1, self.memberEditing.id + 1)
        candidate, issue = Opening.EditMember(candidate, self.memberEditing, self.memberLeader, self.profile)
    else
        candidate, issue = Opening.EditMember(draft, self.memberEditing, self.memberLeader, self.profile)
    end
    return candidate, issue
end

---@param self OpeningEditorController
function OpeningEditor.SaveDraftMember(self)
    local candidate, issue = OpeningEditor.DraftMemberCandidate(self)
    if not candidate then
        self.memberIssue = issue
        render(self)
        return
    end
    local removed = self.memberRemoving
    if self.openingEditDraft then self.openingEditDraft = candidate else self.draft = candidate end
    Opening.EnsureRelicUsers(candidate, self.profile)
    self.undo.people = nil
    self.houseUndo = nil
    self.memberEditing = nil
    self.memberIsNew = nil
    self.memberRemoving = nil
    self.removeConfirm = false
    self.openingView = self.memberReturn or "summary"
    self.openingFeedback = removed and "已移除成员并清理关系引用。" or ""
    render(self)
end

---@param self OpeningEditorController
function OpeningEditor.CancelDraftMember(self)
    self.memberEditing = nil
    self.memberIsNew = nil
    self.memberRemoving = nil
    self.memberIssue = ""
    self.removeConfirm = false
    self.openingView = self.memberReturn or "summary"
    render(self)
end

function OpeningEditor.Apply(App)
    if App.__openingEditorApplied then return App end
    App.__openingEditorApplied = true
    local originalInit = App.Init
    function App:Init(...)
        originalInit(self, ...)
        OpeningEditor.Init(self)
    end
    for name, method in pairs(OpeningEditor) do
        if name ~= "Apply" and name ~= "Init" then App[name] = method end
    end
    return App
end

return OpeningEditor
