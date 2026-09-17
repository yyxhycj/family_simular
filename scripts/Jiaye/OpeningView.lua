-- 手机开局与可选编辑：同一草案，明细只读，长内容在固定操作栏之上滚动。
local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Opening = require "Jiaye.Opening"
local Economy = require "Jiaye.Economy"
local View = {}
local C = { paper = {245,243,237,255}, card = {255,254,250,255}, ink = {38,60,51,255},
    muted = {97,107,99,255}, line = {221,222,218,255}, green = {55,99,77,255}, pale = {232,239,221,255}, warning = {164,78,56,255} }
local function text(value, size, color)
    return UI.Label { text = value, fontSize = size or 15, fontColor = color or C.ink, whiteSpace = "normal", flexShrink = 0 }
end
local function button(label, action, secondary, extra)
    local props = extra or {}
    props.text = label; props.onClick = action; props.height = props.height or 44; props.fontSize = 15
    props.backgroundColor = secondary and C.pale or C.green; props.textColor = secondary and C.ink or {255,255,255,255}
    props.borderRadius = 8; props.flexShrink = 0
    return UI.Button(props)
end
local function panel(children, card)
    return UI.Panel { gap = 8, padding = card and 12 or 0, backgroundColor = card and C.card or nil,
        borderRadius = 10, flexShrink = 0, children = children }
end
local function row(children) return UI.Row { gap = 8, flexShrink = 0, children = children } end
local function signed(n) return (n > 0 and "+" or "") .. tostring(n) end
local function field(value, onChange)
    return UI.TextField { value = value, onChange = onChange, height = 44, fontSize = 16, maxLength = 20,
        backgroundColor = C.card, textColor = C.ink, borderColor = C.line }
end
local function choose(items, value, onChange)
    return UI.Dropdown { options = items, value = value, height = 44, fontSize = 15, maxVisibleItems = 5,
        onChange = function(_, selected) onChange(selected) end }
end
local function quantityControl(label, value, min, max, step, suffix, onChange)
    local function move(delta)
        local nextValue = math.max(min, math.min(max, value + delta))
        if nextValue ~= value then onChange(nextValue) end
    end
    return UI.Panel { gap = 6, children = {
        text(label .. "：" .. tostring(value) .. suffix, 17),
        row({
            button("−", function() move(-step) end, true, { width = 44, height = 44, disabled = value <= min }),
            UI.Panel { flex = 1, height = 44, justifyContent = "center", alignItems = "center", backgroundColor = C.card,
                borderColor = C.line, borderWidth = 1, borderRadius = 8, children = { text(tostring(value) .. suffix, 19) } },
            button("+", function() move(step) end, true, { width = 44, height = 44, disabled = value >= max }),
        }),
    }}
end
local function options(items)
    local result = {}
    for _, item in ipairs(items) do table.insert(result, { value = item.id, label = item.name .. " · " .. tostring(item.cost or 0) .. " 点" }) end
    return result
end
local function show(app, name) app.openingView = name; app.openingFeedback = ""; app:Render() end
local function preview(app)
    local run = State.NewRun(app.draft, app.profile)
    return run and Economy.Preview(run) or nil, run
end
local function relicSummary(app)
    local result = {}
    for _, id in ipairs(app.draft.selectedRelicIds) do local relic = Data.Relic(id); if relic then table.insert(result, relic.name .. " · " .. relic.cost .. " 点") end end
    if #result == 0 then return "未带信物 · 可以空手开篇" end
    local shown = {}
    for index = 1, math.min(2, #result) do table.insert(shown, result[index]) end
    if #result > #shown then table.insert(shown, "其余 " .. tostring(#result - #shown) .. " 件") end
    return table.concat(shown, "；")
end

function View.Summary(app)
    local d = app.draft
    local ledger, run = preview(app)
    local adults = 0; for _, member in ipairs(d.members) do if member.age >= 18 then adults = adults + 1 end end
    local children = {
        row({ UI.Panel { flex = 1, minWidth = 0, children = { text(d.family .. "氏家族", 28) } },
            button("改名", function() app.nameEditing = d.family; show(app, "name") end, true, { width = 58 }),
            button("骰子", function() app:RandomFamilyName() end, true, { width = 58 }) }),
        text(Data.Period(d.periodId).name .. " · " .. Data.Place(d.placeId).short .. " · 大晟历 " .. d.calendar .. " 年", 14, C.muted),
    }
    local metrics = {}
    for _, metric in ipairs({ {"现银", d.money .. " 两"}, {"存粮", d.grain .. " 石"}, {"田地", d.land .. " 亩"}, {"声望",run and tostring(run.reputation) or "待校验"} }) do
        table.insert(metrics, UI.Panel { flex = 1, minWidth = 0, children = { text(metric[1],14,C.muted), text(metric[2],19) } })
    end
    table.insert(children, panel({ row(metrics), text(Data.Home(d.homeId).name .. " · " .. (d.workshop and "有作坊" or "无作坊") .. " · " .. (d.shop and "有商铺" or "无商铺"), 14) },true))
    local leader = State.FindMember(d.members, d.leaderId)
    local leaderJob = leader and Data.Jobs[leader.jobId]
    table.insert(children,panel({ text("家中 " .. #d.members .. " 人 · " .. adults .. " 成人 / " .. (#d.members-adults) .. " 孩子", 16, C.muted),
        text("首任族长 · " .. (leader and leader.name or "未指定") .. " · " .. (leaderJob and leaderJob.name or "安排待校验"), 15),
        button("查看全体 " .. #d.members .. " 人  ›", function() app:OpenOpeningDetail("people") end, true, { height = 44 }) },true))
    table.insert(children,panel({ text("信物 " .. tostring(#d.selectedRelicIds) .. " 件 · " .. relicSummary(app), 14, C.muted),
        button("查看信物与收藏  ›", function() app:OpenOpeningDetail("relics") end, true, { height = 44 }) }, true))
    table.insert(children,button(ledger and ("首年净变化  " .. signed(ledger.netMoney) .. " 两  /  " .. signed(ledger.netGrain) .. " 石  ›") or "首年账本 · 请先修正草案",
        function() app:OpenOpeningDetail("ledger") end,true,{height=48}))
    table.insert(children,text("不含突发事件 · 剩余点数不必花完",14,C.muted))
    if ledger and (not ledger.foodSatisfied or not ledger.moneySatisfied) then table.insert(children,text("首年钱粮可能不足，可调整家底或安排后再开始。",15,C.warning)) end
    return panel(children)
end

local function ledgerView(app)
    local ledger = preview(app)
    if not ledger then return panel({text("草案存在错误，修正后即可查看首年预计收支。",16,C.warning)}) end
    local children = {text("首年账本",23),text("按眼前安排与年初数值计算，不含突发事件。",14,C.muted),
        text("现有 " .. ledger.beforeMoney .. " 两 / " .. ledger.beforeGrain .. " 石",18)}
    for _, entry in ipairs(ledger.members) do
        table.insert(children,text(entry.name .. " · " .. entry.job .. "：" .. signed(entry.money) .. " 两，" .. signed(entry.grain) .. " 石"))
    end
    for _, line in ipairs({"谋生收入 +" .. ledger.income .. " 两", "产业与营造图 +" .. ledger.industryIncome .. " 两",
        "培养支出 −" .. ledger.training .. " 两", "生活开支 −" .. ledger.livingExpense .. " 两", "田地产粮 +" .. ledger.landGrain .. " 石",
        "全年口粮 −" .. ledger.foodNeed .. " 石", "缺粮 " .. ledger.foodShortfall .. " 石；实际可购 " .. ledger.boughtGrain .. " 石 / " .. ledger.foodCost .. " 两",
        "补开支售粮 " .. ledger.grainSold .. " 石 / +" .. ledger.saleIncome .. " 两", "预计年末 " .. ledger.money .. " 两 / " .. ledger.grain .. " 石"}) do table.insert(children,text(line)) end
    if not ledger.foodSatisfied then table.insert(children,text("购粮资金不足，按当前规则全家体魄各减 12。",16,C.warning)) end
    return panel(children,true)
end

local function pointsView(app)
    local children={text("开局点数明细",23),text("共用 100 点，不设类别配额；姓名与性别零点。",14,C.muted)}
    for _, entry in ipairs(State.PointLines(app.draft)) do
        table.insert(children,panel({text(entry.label .. " · " .. entry.cost .. " 点",16),text(entry.effect,14,C.muted)},true))
    end
    return panel(children)
end

local function peopleView(app)
    local children={text("全部 " .. #app.draft.members .. " 位族人",23)}
    for _, member in ipairs(app.draft.members) do
        local stats=Data.Experience(member.experienceId).values
        table.insert(children,panel({text(member.name .. " · " .. member.age .. " 岁" .. (member.id==app.draft.leaderId and " · 首任族长" or ""),18),
            text("资质 " .. member.talent .. "/5 · " .. Data.Jobs[member.jobId].name),
            text("学识 " .. stats.learn .. " / 手艺 " .. stats.skill .. " / 医术 " .. stats.medicine .. " / 经营 " .. stats.trade .. " / 武艺 " .. stats.martial,14,C.muted),
            button("查看与编辑 · " .. member.name,function() app:OpenDraftMember(member.id) end,true)},true))
    end
    table.insert(children,button("添加族人",function() app:BeginOpeningEdit("people"); app:AddMember() end,true))
    return panel(children)
end

local function relicView(app, editing)
    local children={text(editing and "信物选择" or "本局信物与收藏",23),text("解锁是可选资格；只有选中的物件带入本局，共享 100 点。",14,C.muted)}
    for _, relic in ipairs(Data.Relics) do
        local selected=false; for _, id in ipairs(app.draft.selectedRelicIds) do if id==relic.id then selected=true end end
        local unlocked=app.profile.unlockedRelicIds[relic.id]
        local content={text(relic.name .. " · " .. relic.cost .. " 点",18),text(relic.desc,15,C.muted)}
        table.insert(content,editing and button(not unlocked and "尚未解锁" or (selected and "✓ 已带入" or "选入本局"),function() app:ToggleRelic(relic.id) end,not selected,{disabled=not unlocked})
            or text(not unlocked and "尚未解锁" or (selected and "✓ 本局带入" or "已解锁 · 本局未带入"),14))
        table.insert(children,panel(content,true))
    end
    if not editing then table.insert(children,button("调整信物",function() app:BeginOpeningEdit("relics") end,true)) end
    return panel(children)
end

local function editor(app)
    local d,page=app.draft,app.openingPage
    local used,capacity=State.PageBudget(d,page)
    local children={text("只改你在意的选项",22),text("合计 " .. State.TotalPoints(d) .. "/100 · 本页 " .. used .. " 点，可用 " .. capacity .. " 点",14,C.muted)}
    local nav={}; for _, item in ipairs({{"world","世道"},{"people","族人"},{"estate","家底"},{"relics","信物"},{"final","确认"}}) do
        table.insert(nav,button(item[2],function() app:SetOpeningPage(item[1]) end,item[1]~=page))
    end
    table.insert(children,UI.Panel { flexDirection = "row", flexWrap = "wrap", gap = 8, children = nav })
    if page~="final" then table.insert(children,row({button("随机本页",function() app:RandomizePage(page) end,true,{flex=1}),button("撤销本页随机",function() app:UndoPage(page) end,true,{flex=1,disabled=not app.undo[page]})})) end
    local function choice(title, key, list, selected, effect)
        table.insert(children,text(title,17))
        table.insert(children,choose(list,selected,function(value) app:SetDraftField(page,key,value) end))
        if effect then table.insert(children,text(effect,14,C.muted)) end
    end
    if page=="world" then
        table.insert(children,text("凡世王朝 · 家族称谓在摘要中单独修改",15,C.muted))
        table.insert(children,choose(options(Data.Periods),d.periodId,function(id) app:SelectPeriod(id) end))
        local years={}; for _, y in ipairs(Data.Period(d.periodId).years) do table.insert(years,{value=y,label="大晟历 " .. y .. " 年"}) end
        choice("年份","calendar",years,d.calendar)
        choice("来历","originId",options(Data.Origins),d.originId,Data.Origin(d.originId).desc)
        local place=Data.Place(d.placeId)
        choice("落脚地区","placeId",options(Data.Places),d.placeId,place.desc .. "\n" .. place.burden)
    elseif page=="people" then table.insert(children,peopleView(app))
    elseif page=="estate" then
        for _, item in ipairs({{"money","现银",300,Data.OpeningCosts.moneyUnit," 两"},{"grain","存粮",160,Data.OpeningCosts.grainUnit," 石"},{"land","田地",12,1," 亩"}}) do
            local key=item[1]
            table.insert(children,quantityControl(item[2], d[key], 0, item[3], item[4], item[5], function(v) app:SetDraftField(page,key,v) end))
        end
        choice("住宅","homeId",options(Data.Homes),d.homeId)
        for _, item in ipairs({{"workshop","木工作坊",Data.OpeningCosts.workshop},{"shop","小商铺",Data.OpeningCosts.shop}}) do
            local key=item[1]; table.insert(children,button((d[key] and "✓ " or "") .. item[2] .. " · " .. item[3] .. " 点",function() app:SetDraftField(page,key,not d[key]) end,not d[key]))
        end
        choice("家风","habitId",options(Data.Habits),d.habitId,Data.Habit(d.habitId).desc)
        choice("往来关系","tieId",options(Data.Ties),d.tieId,Data.Tie(d.tieId).desc)
    elseif page=="relics" then table.insert(children,relicView(app,true))
    else
        table.insert(children,pointsView(app)); table.insert(children,ledgerView(app))
        local prior = app.previousDraft ~= nil
        table.insert(children, panel({
            text(prior and "原家谱存档" or "草案存档", 18),
            text(prior and "正在试配新家谱：保存、导出和读取只处理原家谱；新草案仅在“就从这家开始”后写入。" or "保存会先校验并结束当前编辑；导出当前候选草案不会写入存档。", 14, C.muted),
            row({
                button(prior and "保存原家谱" or "保存草案", function() app:SaveOpeningDraft() end, true, { flex = 1, height = 40 }),
                button(prior and "导出原家谱" or "导出当前候选草案", function() app:Export() end, true, { flex = 1, height = 40 }),
            }),
            button("读取最近存档", function() app:Load() end, true, { height = 40 }),
        }, true))
    end
    return panel(children)
end

local function memberView(app)
    local m=app.memberEditing
    local children={text(m.name .. " · 临时编辑",23),text("人物 " .. State.MemberCost(m) .. " 点；保存后生效，取消不改草案。",14,C.muted)}
    local tabs={}; for _, item in ipairs({{"base","概况"},{"skills","本领与安排"},{"relations","亲属"}}) do
        table.insert(tabs,button(item[2],function() app.memberSection=item[1]; app:Render() end,item[1]~=app.memberSection,{flex=1}))
    end
    table.insert(children,row(tabs))
    local function change(key,value) m[key]=value; app.memberIssue=""; app.removeConfirm=false; app:Render() end
    if app.memberSection=="base" then
        table.insert(children,text("完整姓名 · 手改后独立保留"))
        -- 输入时不重建整棵树，避免 TextField 丢失焦点；保存前仍由 EditMember 完整校验。
        table.insert(children,field(m.name,function(_,value) m.name=value; m.nameSource="custom"; app.memberIssue=""; app.removeConfirm=false end))
        table.insert(children,button(m.nameSource=="family" and "✓ 跟随家族姓氏" or "改为跟随家族姓氏",function()
            m.nameSource="family"; m.givenName=m.givenName or "新"; m.name=app.draft.family .. m.givenName; app.removeConfirm=false; app:Render()
        end,true))
        if m.nameSource=="family" then
            table.insert(children,text("本姓成员的名（不含姓）"))
            table.insert(children,field(m.givenName,function(_,value) m.givenName=value; m.name=app.draft.family .. value; app.memberIssue=""; app.removeConfirm=false end))
        end
        table.insert(children,quantityControl("年龄", m.age, 0, 92, 1, " 岁", function(v) change("age",v) end))
        table.insert(children,choose({{value="男",label="男"},{value="女",label="女"}},m.sex,function(v) change("sex",v) end))
        table.insert(children,button(app.memberLeader==m.id and "✓ 首任族长" or "设为首任族长",function() app.memberLeader=m.id; app:Render() end,true,{disabled=m.age<18}))
    elseif app.memberSection=="skills" then
        local talents={}; for i,t in ipairs(Data.Talents) do table.insert(talents,{value=i,label=t.name .. " · " .. t.cost .. " 点"}) end
        table.insert(children,text("潜力资质")); table.insert(children,choose(talents,m.talent,function(v) change("talent",v) end))
        local focuses={}; for _,id in ipairs({"general","learn","skill","medicine","trade","martial"}) do table.insert(focuses,{value=id,label=Data.FocusNames[id]}) end
        table.insert(children,text("偏向 · 零点")); table.insert(children,choose(focuses,m.focus,function(v) change("focus",v) end))
        table.insert(children,text("已有本领"))
        local experiences=options(Data.Experiences)
        for i,item in ipairs(Data.Experiences) do experiences[i].disabled=m.age<8 and item.id~="none" or m.age<18 and item.id~="none" and item.id~="basic" end
        table.insert(children,choose(experiences,m.experienceId,function(v) change("experienceId",v) end))
        local values=Data.Experience(m.experienceId).values
        table.insert(children,text("学识 " .. values.learn .. " / 手艺 " .. values.skill .. " / 医术 " .. values.medicine .. " / 经营 " .. values.trade .. " / 武艺 " .. values.martial,15,C.muted))
        table.insert(children,text("初始安排 · 不满足资格时先改年龄或本领"))
        local jobs={}
        for _, id in ipairs(Data.JobOrder) do
            local ok,reason=State.CanUseJob({age=m.age,stats=values},id)
            table.insert(jobs,{value=id,label=Data.Jobs[id].name .. (ok and "" or " · " .. reason),disabled=not ok})
        end
        table.insert(children,choose(jobs,m.jobId,function(v) change("jobId",v) end))
        table.insert(children,text(Data.Jobs[m.jobId].desc,14,C.muted))
    else
        table.insert(children,text("父母/养亲 · 最多两位；年龄变更不会偷偷删除关系。",15,C.muted))
        for _, other in ipairs(app.draft.members) do if other.id~=m.id then
            local selected=false; for _,id in ipairs(m.parents) do if id==other.id then selected=true end end
            table.insert(children,button((selected and "✓ " or "") .. other.name .. " · " .. other.age .. " 岁",function()
                local nextParents={}; for _,id in ipairs(m.parents) do if id~=other.id then table.insert(nextParents,id) end end
                if not selected then table.insert(nextParents,other.id) end
                change("parents",nextParents)
            end,not selected,{disabled=not selected and (other.age-m.age<18 or #m.parents>=2)}))
        end end
        local spouses={{value=0,label="无配偶"}}
        for _,other in ipairs(app.draft.members) do if other.id~=m.id then table.insert(spouses,{value=other.id,label=other.name .. " · " .. other.age .. " 岁",disabled=other.age<18 or m.age<18}) end end
        table.insert(children,text("配偶 · 保存时双向校验")); table.insert(children,choose(spouses,m.spouseId or 0,function(v) change("spouseId",v~=0 and v or nil) end))
        if not app.memberIsNew then
            table.insert(children,button(app.removeConfirm and "确认移除，并清理配偶/亲子引用" or "移除此人…",function()
                if app.removeConfirm then app.removeConfirm=false; app:RemoveMember(m.id) else app.removeConfirm=true; app:Render() end
            end,true))
        end
    end
    local candidate,issue=app:DraftMemberCandidate()
    table.insert(children,text(candidate and ("保存后总分 " .. State.TotalPoints(candidate) .. "/100") or issue,15,candidate and C.muted or C.warning))
    if app.memberIssue~="" then table.insert(children,text(app.memberIssue,15,C.warning)) end
    return panel(children)
end

function View.Build(app)
    local view=app.openingView or "summary"
    local content,footer,title
    title=view=="summary" and "家业 · 凡世王朝" or "家业 · 开局草案"
    if view=="summary" then content=View.Summary(app)
    elseif view=="ledger" then content=ledgerView(app)
    elseif view=="points" then content=pointsView(app)
    elseif view=="people" then content=peopleView(app)
    elseif view=="relics" then content=relicView(app,false)
    elseif view=="editor" then content=editor(app)
    elseif view=="member" then content=memberView(app)
    elseif view=="name" then
        content=panel({text("家族称谓",24),text("零点；只同步明确跟随家姓的成员，外姓与手改完整姓名保留。",15,C.muted),
            field(app.nameEditing,function(_,value) app.nameEditing=value end)})
    end
    if view=="summary" then
        local issues=State.ValidateDraft(app.draft,app.profile,false)
        footer={button("总计 " .. State.TotalPoints(app.draft) .. "/100 点 · 查看明细  ›",function() app:OpenOpeningDetail("points") end,true),
            row({button("换一家",function() app:ChangeHouse() end,true,{flex=1,height=48}),button("就从这家开始",function() app:StartRun() end,false,{flex=2,height=48,disabled=#issues>0})}),
            button("只改我在意的选项",function() app:BeginOpeningEdit() end,true)}
        if #issues>0 then table.insert(footer,1,text(table.concat(issues,"\n"),14,C.warning)) end
        if app.houseUndo then table.insert(footer,button("恢复上一家",function() app:UndoHouse() end,true)) end
    elseif view=="editor" then
        footer={text("总计 " .. State.TotalPoints(app.draft) .. "/100 · 超分可保留编辑，但不能开局",14,C.muted),
            row({button("取消编辑",function() app:FinishOpeningEdit(false) end,true,{flex=1}),button("保存并返回",function() app:FinishOpeningEdit(true) end,false,{flex=1})})}
    elseif view=="member" then
        footer={row({button("取消",function() app:CancelDraftMember() end,true,{flex=1}),button("保存人物",function() app:SaveDraftMember() end,false,{flex=1})})}
    elseif view=="name" then
        footer={row({button("取消",function() show(app,"summary") end,true,{flex=1}),button("保存姓名",function()
            local ok,message=Opening.Rename(app.draft,app.nameEditing)
            if ok then app:MarkOpeningPageChanged("people"); app.openingView="summary" end
            app.openingFeedback=message; app:Render()
        end,false,{flex=1})})}
    else footer={button("返回这户家庭",function() app:ReturnOpeningDetail() end,true)} end
    local body={content}
    if app.openingFeedback~="" then table.insert(body,1,text(app.openingFeedback,14,C.warning)) end
    local header={UI.Panel {flex=1,children={text(title,18)}}}
    if app.previousDraft then table.insert(header,button("回原家谱",function() app:CancelNewRun() end,true)) end
    return UI.Panel {width="100%",height="100%",backgroundColor=C.paper,children={
        UI.Panel {padding=12,borderBottomWidth=1,borderBottomColor=C.line,flexShrink=0,children={row(header)}},
        UI.ScrollView {flexGrow=1,flexBasis=0,minHeight=0,padding=12,children={panel(body)}},
        UI.Panel {padding=12,gap=6,backgroundColor=C.card,flexShrink=0,borderTopWidth=1,borderTopColor=C.line,children=footer},
    }}
end
return View
