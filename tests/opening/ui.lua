-- 开局 UI 回调边界：运行在 t01 的声明式 UI 适配层，不替代真机验收。
local App = require "Jiaye.App"
local Opening = require "Jiaye.Opening"
local State = require "Jiaye.State"

local function same(a, b) return cjson.encode(a) == cjson.encode(b) end

local function findKind(root, kind)
    if root.kind == kind then return root end
    for _, child in ipairs(root.children or {}) do
        local found = findKind(child, kind)
        if found then return found end
    end
end

local function findText(root, value)
    if root.text == value then return root end
    for _, child in ipairs(root.children or {}) do
        local found = findText(child, value)
        if found then return found end
    end
end

local function run()
    -- 故障注入只验证首次生成失败的控制流，不作为生成器能力证据。
    local originalGenerate, attempts = Opening.Generate, 0
    Opening.Generate = function()
        attempts = attempts + 1
        return nil, "注入生成失败"
    end
    local failed = App.New()
    assert(failed.screen == "cover" and failed.openingGenerationFailed and failed.openingFeedback == "注入生成失败")
    failed:Render()
    assert(findText(UI.root, "立一部家谱") and findText(UI.root, "读取最近存档"), "失败封面按钮不可达")
    failed:PrepareNewRun()
    assert(attempts == 2 and failed.screen == "cover" and failed.openingGenerationFailed and State.Load() == nil,
        "首次生成失败不应暴露固定草案或写入存档")
    Opening.Generate = originalGenerate
    failed:PrepareNewRun()
    assert(failed.screen == "opening" and not failed.openingGenerationFailed, "封面明确重试成功后应进入开局")

    local app = App.New()
    app.screen = "opening"
    app.openingView = "summary"
    app.screen = "cover"; app.openingGenerationFailed = false; app:Render()
    assert(findText(UI.root, "立一部家谱") and findText(UI.root, "读取最近存档"), "正常封面按钮不可达")
    app.screen = "opening"; app:Render()
    assert(findText(UI.root, "一家人的故事，从这里开始") and findText(UI.root, "首年预计净变化")
        and findText(UI.root, "只改我在意的选项") and findKind(UI.root, "SimpleGrid"),
        "随机开局没有渲染设计稿要求的摘要层级与成员入口")

    -- 新成员必须先留在临时编辑对象；取消不可占用编号或污染草案。
    local beforeAdd = State.Copy(app.draft)
    app:BeginOpeningEdit("people")
    app:AddMember()
    assert(app.memberIsNew and #app.draft.members == #beforeAdd.members)
    assert(app.draft.nextId == beforeAdd.nextId)
    local newCandidate, newIssue = app:DraftMemberCandidate()
    assert(newCandidate and not newIssue and #newCandidate.members == #beforeAdd.members + 1,
        "新增成员没有使用最终候选草案预估")
    local input = assert(findKind(UI.root, "TextField"), "missing member name field")
    local rendered = UI.root
    input.onChange(input, "临时全名")
    assert(UI.root == rendered and app.memberEditing.name == "临时全名" and app.memberEditing.nameSource == "custom",
        "完整姓名输入重绘了页面或未保留临时值")
    app:CancelDraftMember()
    assert(same(app.draft, beforeAdd), "取消新增成员修改了草案")

    -- 从关系页真实选择新成员配偶：保存后必须双向连接，并清理对方旧配偶。
    app.draft = State.NewDraft()
    app:BeginOpeningEdit("people")
    app:AddMember()
    app.memberSection = "relations"; app:Render()
    assert(not findText(UI.root, "移除此人…"), "未保存成员不应出现移除草案操作")
    local spouseSelect = assert(findKind(UI.root, "Dropdown"), "missing new-member spouse selector")
    spouseSelect.onChange(spouseSelect, 2)
    app:SaveDraftMember()
    local newMember = State.FindMember(app.draft.members, app.draft.nextId - 1)
    assert(newMember.spouseId == 2 and State.FindMember(app.draft.members, 2).spouseId == newMember.id
        and State.FindMember(app.draft.members, 1).spouseId == nil, "新增成员婚配没有双向保存或清理旧配偶")
    app:FinishOpeningEdit(true)

    -- 保存先结束编辑；之后取消另一轮未保存改动，不得倒写或覆盖已保存草案。
    app:BeginOpeningEdit("estate")
    app:SetDraftField("estate", "money", 90)
    assert(app:SaveOpeningDraft())
    local storedAfterSave = State.Copy(assert(State.Load()))
    app:BeginOpeningEdit("estate")
    app:SetDraftField("estate", "money", 100)
    assert(app:FinishOpeningEdit(false))
    assert(app.draft.money == 90 and assert(State.Load()).draft.money == storedAfterSave.draft.money,
        "取消编辑覆盖了已保存草案")

    -- 当前页手改清除该页撤销，不影响其他页的撤销记录。
    app.undo.world = { before = Opening.Snapshot(app.draft, "world"), after = Opening.Snapshot(app.draft, "world") }
    app.undo.estate = { before = Opening.Snapshot(app.draft, "estate"), after = Opening.Snapshot(app.draft, "estate") }
    app:SetDraftField("world", "originId", app.draft.originId)
    assert(app.undo.world == nil and app.undo.estate ~= nil)

    -- 编辑器取消恢复整份草案；只读明细回到原开局页。
    local beforeEdit = State.Copy(app.draft)
    app:BeginOpeningEdit("estate")
    app:SetDraftField("estate", "money", app.draft.money + 10)
    app:FinishOpeningEdit(false)
    assert(same(app.draft, beforeEdit), "取消编辑修改了草案")
    app:OpenOpeningDetail("points")
    assert(app.openingView == "points")
    app:ReturnOpeningDetail()
    assert(app.openingView == "summary")
    app.openingView = "editor"
    app:OpenOpeningDetail("ledger")
    app:ReturnOpeningDetail()
    assert(app.openingView == "editor", "明细没有返回原页面")

    -- 非法草案保持在摘要页、按钮可禁用所依据的错误同时就地展示。
    app.draft.money = 999
    app:StartRun()
    assert(app.screen == "opening" and app.run == nil)
    assert(app.openingFeedback ~= "")

    return { generatedFailureInjected = true, coverActionsReachable = true, addCancelPure = true, newMemberPreview = true, newMemberSpouseSaved = true, savedDraftSurvivesLaterCancel = true, pageUndoScoped = true, editCancelPure = true, inputKeepsFocus = true,
        detailReturnPreserved = true, invalidStartInline = true }
end

return { run = run }
