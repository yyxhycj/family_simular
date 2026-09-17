-- T05 只验证可选编辑器的草案边界；声明式 UI 适配层不能替代引擎布局或真机输入。
local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Opening = require "Jiaye.Opening"
local State = require "Jiaye.State"

local function same(left, right) return Opening.Equal(left, right) end

local function find(root, matches)
    if matches(root) then return root end
    for _, child in ipairs(root.children or {}) do
        local found = find(child, matches)
        if found then return found end
    end
end

local function text(root, value)
    return find(root, function(node) return node.text == value end)
end

local function kinds(root, kind, result)
    result = result or {}
    if root.kind == kind then table.insert(result, root) end
    for _, child in ipairs(root.children or {}) do kinds(child, kind, result) end
    return result
end

local function memberWithParents(draft)
    for _, member in ipairs(draft.members) do if #member.parents > 0 then return member end end
end

local function lowBudgetDraft(profile)
    for seed = 1, 128 do
        local draft = assert(Opening.Generate(profile, seed, "mortal"))
        if State.TotalPoints(draft) <= 88 and memberWithParents(draft) then return draft end
    end
    error("没有可用于单项编辑且含亲缘关系的低预算生成草案")
end

local function assertNoReference(draft, memberId)
    for _, member in ipairs(draft.members) do
        assert(member.spouseId ~= memberId, "移除后仍保留配偶引用")
        for _, parentId in ipairs(member.parents) do assert(parentId ~= memberId, "移除后仍保留亲缘引用") end
    end
end

local function run()
    local profile = State.NewProfile()
    local app = App.New()
    app.profile, app.draft, app.run = profile, lowBudgetDraft(profile), nil
    app.screen, app.openingView = "opening", "summary"
    app:Render()
    local original = State.Copy(app.draft)

    -- 摘要可直达世道或家底，不清空已生成草案。
    local world = assert(text(UI.root, "调整世道与来历"))
    world.onClick(world)
    assert(app.openingView == "editor" and app.openingPage == "world" and same(app.draft, original), "摘要不能直达世道或直达时重置草案")
    assert(app:FinishOpeningEdit(false) and same(app.draft, original), "未改世道取消却改写草案")
    app:Render()
    local estate = assert(text(UI.root, "调整家底"))
    estate.onClick(estate)
    local expected = State.Copy(original)
    expected.money = expected.money + 10
    app:SetDraftField("estate", "money", expected.money)
    assert(app:FinishOpeningEdit(true) and app.openingView == "summary" and same(app.draft, expected), "只改家底保存后摘要不一致")

    -- 既有成员的姓名、性别、偏向与初始安排使用临时副本，姓名/性别/偏向/岗位不额外计点。
    local person = app.draft.members[1]
    local pointsBeforeMember = State.TotalPoints(app.draft)
    app:BeginOpeningEdit("people")
    local edit = assert(text(UI.root, "查看与编辑 · " .. person.name))
    edit.onClick(edit)
    local nameField = assert(kinds(UI.root, "TextField")[1])
    nameField.onChange(nameField, "欧阳自定")
    local sex = assert(kinds(UI.root, "Dropdown")[1])
    sex.onChange(sex, person.sex == "男" and "女" or "男")
    app.memberSection = "skills"; app:Render()
    local controls = kinds(UI.root, "Dropdown")
    controls[2].onChange(controls[2], "trade")
    controls[4].onChange(controls[4], "farm")
    app:SaveDraftMember()
    local edited = assert(State.FindMember(app.draft.members, person.id))
    assert(edited.name == "欧阳自定" and edited.nameSource == "custom" and edited.focus == "trade" and edited.jobId == "farm"
        and State.TotalPoints(app.draft) == pointsBeforeMember, "人物单项保存未保留零点姓名/性别/偏向/安排边界")
    assert(app:FinishOpeningEdit(false) and same(app.draft, expected), "整次编辑取消没有回到进入编辑前的摘要草案")

    -- 年龄改变造成亲缘或岗位非法时，保存失败且临时草案不倒写。
    local related = memberWithParents(app.draft)
    assert(related, "夹具必须含有可验证亲缘的成员")
    local beforeInvalid = State.Copy(app.draft)
    app:OpenDraftMember(related.id)
    app.memberEditing.age = 92
    app:SaveDraftMember()
    assert(app.openingView == "member" and app.memberIssue:find("亲缘关系无效", 1, true) and same(app.draft, beforeInvalid),
        "年龄造成非法亲缘时仍写入草案")
    app:CancelDraftMember()

    -- 删除先是临时标记：取消不写；保存后才清理引用。删除首任族长会就地失败。
    local leaderBeforeDelete = State.Copy(app.draft)
    app:OpenDraftMember(app.draft.leaderId)
    app:MarkDraftMemberForRemoval()
    assert(app.memberRemoving and same(app.draft, leaderBeforeDelete), "标记删除提前改写草案")
    app:SaveDraftMember()
    assert(app.memberIssue:find("成年首任族长", 1, true) and same(app.draft, leaderBeforeDelete), "删除首任族长没有被保存校验阻止")
    app:CancelDraftMember()

    local target = nil
    for _, member in ipairs(app.draft.members) do if member.id ~= app.draft.leaderId then target = member; break end end
    assert(target, "夹具必须有可删除的非族长成员")
    app:OpenDraftMember(target.id)
    app:MarkDraftMemberForRemoval()
    assert(same(app.draft, leaderBeforeDelete), "删除确认前污染草案")
    app:CancelDraftMember()
    assert(same(app.draft, leaderBeforeDelete), "取消删除没有恢复草案")
    app:OpenDraftMember(target.id)
    app:MarkDraftMemberForRemoval()
    app:SaveDraftMember()
    assert(not State.FindMember(app.draft.members, target.id) and #app.draft.members == #leaderBeforeDelete.members - 1, "保存移除没有提交成员候选")
    assertNoReference(app.draft, target.id)

    -- 本页随机撤销不覆盖异页手改；超分可继续编辑但不能开始。
    app:BeginOpeningEdit("estate")
    local estateBeforeRandom = Opening.Snapshot(app.draft, "estate")
    app:RandomizePage("estate")
    local otherOrigin = app.draft.originId == "plain" and "artisan" or "plain"
    app:SetDraftField("world", "originId", otherOrigin)
    app:UndoPage("estate")
    assert(same(Opening.Snapshot(app.draft, "estate"), estateBeforeRandom) and app.draft.originId == otherOrigin,
        "本页撤销覆盖了异页手改")
    app:FinishOpeningEdit(false)
    app:BeginOpeningEdit("estate")
    app:SetDraftField("estate", "money", 1500)
    assert(app:FinishOpeningEdit(true) and State.TotalPoints(app.draft) > 100, "超分草案没有保留供继续编辑")
    local retained = State.Copy(app.draft)
    app:StartRun()
    assert(app.run == nil and app.openingFeedback:find("总分超过 100", 1, true) and same(app.draft, retained), "超分草案仍可开始或被自动改写")

    -- 保存当前可用草案，独立 VM 读取后仍返回摘要且不丢成员关系。
    app.draft = State.Copy(leaderBeforeDelete)
    app.screen, app.openingView = "opening", "summary"; app:Render()
    assert(app:Save())
    assert(same(State.Load().draft, app.draft))
    return {
        id = "optional_editor",
        directPages = { "world", "estate" },
        memberFields = { "name", "sex", "focus", "job" },
        invalidAgePreserved = true,
        deletionCancelPure = true,
        deletionSaveCleansReferences = true,
        pageUndoScoped = true,
        overBudgetBlocked = true,
    }
end

local function restart()
    local app = App.New()
    app:Load()
    assert(app.screen == "opening" and app.run == nil and #State.ValidateDraft(app.draft, app.profile, false) == 0,
        "重启读取后的可选编辑草案无效或未回到摘要")
    return { id = "restart", family = app.draft.family, members = #app.draft.members, points = State.TotalPoints(app.draft) }
end

return { run = run, restart = restart }
