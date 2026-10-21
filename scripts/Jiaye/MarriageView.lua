local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Marriage = require "Jiaye.Marriage"
local Economy = require "Jiaye.Economy"
local Art = require "Jiaye.Art"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"
local ModalLayout = require "Jiaye.ModalLayout"

local MarriageView = {}
local M, C = Marriage.Rules, V7.Colors
local function Text(value, props)
    props = props or {}; props.fontSize = props.fontSize or 15; props.whiteSpace = "normal"; props.lineHeight = 1.5
    return Visual.Text(value, props)
end
local function Button(value, action, props)
    props = props or {}; props.height = props.height or 46; props.fontSize = props.fontSize or 15
    props.role = props.role or "secondary"; props.width = props.width or "100%"
    return Visual.Button(value, action, props)
end
local function Card(children, props) return Visual.Card(children, props or { padding = 12, gap = 8 }) end
local function Person(run, id) return State.FindMember(run.members, id) end
local function Name(run, id) local person = Person(run, id); return person and person.name or "未指定" end
local function Status(status) return ({ active = "进行中", paused = "已暂停", completed = "已完成", cancelled = "已结束", expired = "已到期", ended = "已结清", awaiting = "待接手", archived = "已封存" })[status] or status end
local function Kin(run, contract) return M.Find(run.marriage.households, contract.householdId) end
local function HasValue(list, value) for _, item in ipairs(list) do if item == value then return true end end return false end
local function Identity(family)
    local patron = family.patron
    return patron.name .. " · " .. patron.title .. " · " .. patron.age .. "岁 · " .. (not patron.alive and "已故" or patron.active and ("在任，" .. patron.retireAge .. "岁退任") or "已退任")
end
local function AidText(aid)
    if not aid then return "亲家本轮援助名额已另有约定。" end
    local names = { grain = "粮食", money = "银两", learn = "学识", skill = "手艺", medicine = "医术", martial = "武艺" }
    return "亲家援助：" .. names[aid.kind] .. "每次+" .. aid.amount .. "，剩余" .. aid.remaining .. "次；6年内配合实际安排生效。"
end
local function DutyText(duty)
    if duty.kind == "care" then return "接长辈入户，3年内由其他成年族人实际持家；合格年得2两、2石，缺照料每年声望-2、最多-4；长辈离世结束。" end
    if duty.kind == "land" then return "亲家赠1亩限售田；在此地住满5年且7年内实际耕作5年后取得自由田契。提前离开或逾期归还田地、声望-4；自然离世可由后人接手或归还。" end
    return "指定受惠人4年内在此地实际“" .. Data.Jobs[duty.job].name .. "”2年，减免聘资" .. duty.rebate .. "两；主动迁出或逾期返还减免、声望-2。"
end

function MarriageView.Open(app, memberId)
    local member = Person(app.run, memberId)
    if not member then return end
    local page = member.marriageId and "family" or "candidates"
    local input = { weddingId = "simple", childHome = "home" }
    local sheet, render, chooser
    local function Go(nextPage) page = nextPage; render() end
    local function Act(action)
        if sheet then sheet:Destroy() end
        app:RunAction(action)
        page = "family"; render()
    end
    local function Choose(title, action, reason, back)
        chooser = { title = title, action = action, reason = reason, back = back or "family" }; Go("choose")
    end
    local function ContractCards(run, children)
        local found = false
        for _, contract in ipairs(run.marriage.contracts) do
            if contract.memberId == memberId or contract.spouseId == memberId then
                found = true
                local family = Kin(run, contract)
                local lines = {
                    Text(Name(run, contract.memberId) .. " 与 " .. Name(run, contract.spouseId), { fontSize = 23 }),
                    Text(family.name .. " · " .. Data.Place(family.placeId).short .. " · " .. M.Find(M.Forms, contract.form).name, { fontColor = C.primary }),
                    Text(Identity(family), { fontSize = 13, fontColor = C.secondary }),
                    Text(family.history .. "现在希望“" .. family.needText .. "”。"),
                    Text("成婚第" .. (run.yearIndex - contract.year + 1) .. "年 · 孩子归" .. (contract.childHome == "home" and "本家" or "亲家")),
                    Text(AidText(contract.aid), { fontSize = 13, fontColor = C.secondary }),
                }
                for _, duty in ipairs(contract.duties) do
                    table.insert(lines, Text(duty.name .. " · " .. Status(duty.status) .. " · " .. duty.progress .. "/" .. duty.required .. "年 · 截止家族第" .. (duty.deadline + 1) .. "年", { fontColor = C.primary }))
                    table.insert(lines, Text(DutyText(duty), { fontSize = 13, fontColor = C.secondary }))
                    if duty.targetId then table.insert(lines, Text("守约人：" .. Name(run, duty.targetId), { fontSize = 13 })) end
                    if duty.status == "active" or duty.status == "awaiting" then
                        if duty.kind == "land" and not Person(run, contract.memberId).alive and not Person(run, contract.spouseId).alive then
                            table.insert(lines, Button("指定守业接手人", function()
                                Choose("由谁接手“" .. duty.name .. "”", function(current, id) return Marriage.DutyAction(current, contract.id, duty.kind, "takeover", id) end,
                                    function(current, id) return Marriage.DutyReason(current, contract.id, duty.kind, id) end)
                            end))
                        end
                        table.insert(lines, Button("结束并结清约定", function()
                            app:ConfirmRunAction("结清“" .. duty.name .. "”", DutyText(duty), function(current) return Marriage.DutyAction(current, contract.id, duty.kind, "end") end, "按约结清", sheet)
                        end))
                    end
                end
                local kind = family.patron.role
                if contract.aid and contract.aid.remaining > 0 then
                    table.insert(lines, Text("受惠人：" .. Name(run, contract.aid.targetId), { fontSize = 13 }))
                    table.insert(lines, Button("更换资助受惠人", function()
                        Choose("由谁承接剩余资助", function(current, id) return Marriage.SetAidTarget(current, contract.id, id) end)
                    end))
                end
                table.insert(lines, Text(M.Projects[kind].name, { fontSize = 18 }))
                table.insert(lines, Text(M.Projects[kind].detail, { fontSize = 13 }))
                table.insert(lines, Button("选择办理人", function()
                    Choose(M.Projects[kind].name, function(current, id) return Marriage.StartProject(current, contract.id, kind, id) end,
                        function(current, id) return Marriage.ProjectReason(current, contract.id, kind, id) end)
                end, { disabled = app.run.ending ~= nil }))
                table.insert(children, Card(lines))
            end
        end
        if not found then table.insert(children, Card({ Text("此人暂无与亲家约定的资助及事务。成年后可通过议亲认识具体对象。") })) end
    end
    local function Affairs(run, children)
        for _, project in ipairs(run.marriage.projects) do
            local contract = M.Find(run.marriage.contracts, project.contractId)
            if contract.memberId == memberId or contract.spouseId == memberId then
                local definition = M.Projects[project.kind]
                local lines = {
                    Text(definition.name .. " · " .. Status(project.status), { fontSize = 19 }),
                    Text(Name(run, project.actorId) .. " · " .. project.progress .. "/" .. (definition.charges or definition.work) .. "个实际工作年 · 截止第" .. (project.deadline + 1) .. "年"),
                    Text(definition.detail, { fontSize = 13, fontColor = C.secondary }),
                }
                if project.status == "active" or project.status == "paused" then
                    table.insert(lines, Button(project.status == "active" and "暂停办理" or "恢复办理", function() Act(function(current) return Marriage.ProjectAction(current, project.id, project.status == "active" and "pause" or "resume") end) end))
                    table.insert(lines, Button("结束事务 · 可退" .. project.unspent .. "两", function()
                        app:ConfirmRunAction("结束“" .. definition.name .. "”", "退回未用款" .. project.unspent .. "两，已花费用与消耗材料留在账目中。", function(current) return Marriage.ProjectAction(current, project.id, "cancel") end, "确认结束", sheet)
                    end))
                end
                table.insert(children, Card(lines))
            end
        end
        for _, story in ipairs(run.marriage.stories) do
            local contract = M.Find(run.marriage.contracts, story.contractId)
            if story.status == "pending" and (contract.memberId == memberId or contract.spouseId == memberId) then
                table.insert(children, Card({ Text(story.title, { fontSize = 21 }), Text(story.detail),
                    Button("照约办理", function()
                        if story.kind == "legacy" then Choose("由谁保管旧书", function(current, id) return Marriage.ResolveStory(current, story.id, true, id) end)
                        else Act(function(current) return Marriage.ResolveStory(current, story.id, true) end) end
                    end),
                    Button("婉言谢过", function() Act(function(current) return Marriage.ResolveStory(current, story.id, false) end) end),
                }, { borderColor = C.gold, padding = 12, gap = 8 }))
            end
        end
    end
    local function Heritage(run, children)
        for _, tradition in ipairs(run.marriage.traditions) do
            local holder = Person(run, tradition.holderId)
            local lines = { Text(M.Traits[tradition.kind].name .. " · " .. holder.name, { fontSize = 20 }), Text(M.Traits[tradition.kind].detail, { fontSize = 14 }),
                Button("选择受教人", function()
                    Choose("向谁传习“" .. M.Traits[tradition.kind].name .. "”", function(current, id) return Marriage.Teach(current, holder.id, id) end,
                        function(current, id) return Marriage.TeachReason(current, holder.id, id) end, "heritage")
                end),
            }
            if tradition.kind == "farming" then
                table.insert(lines, Button("指定本代读书人", function()
                    Choose("本代由谁承接耕读名额", function(current, id) return Marriage.SetReader(current, tradition.id, id) end,
                        function(current, id) return Marriage.ReaderReason(current, tradition.id, id) end, "heritage")
                end))
            end
            table.insert(children, Card(lines))
        end
        for _, lesson in ipairs(run.marriage.lessons) do
            table.insert(children, Card({ Text(Name(run, lesson.mentorId) .. " → " .. Name(run, lesson.studentId), { fontSize = 18 }),
                Text(M.Traits[lesson.kind].name .. " · " .. Status(lesson.status) .. " · " .. lesson.progress .. "/" .. (lesson.kind == "farming" and 3 or 2)),
                lesson.status == "active" and Button("暂停传习", function() Act(function(current) return Marriage.PauseLesson(current, lesson.id) end) end) or Text("可从同一家法的师长处接续进度。", { fontSize = 13 }),
            }))
        end
        for _, object in ipairs(run.marriage.objects) do
            table.insert(children, Card({ Text((object.kind == "book" and "亲家旧书" or "作坊旧图") .. " · " .. Name(run, object.holderId), { fontSize = 18 }),
                Text(object.kind == "book" and ("实际读书时学识+2，剩余" .. object.charges .. "次，可跨代接手。") or (object.consumed and "图纸已用于改坊。" or "可用于所属婚约的旧图改坊事务。")),
                Button("交给族人保管", function() Choose("由谁接手物件", function(current, id) return Marriage.GiveObject(current, object.id, id) end, nil, "heritage") end, { disabled = object.consumed or (object.charges and object.charges <= 0) }),
            }))
        end
        if #children == 1 then table.insert(children, Text("家法需通过相应婚约取得，受教人完成实际传习后才会继承。")) end
    end
    render = function()
        if sheet then sheet:Destroy() end
        local run = app.run
        member = Person(run, memberId)
        sheet = ModalLayout.New("议亲 · " .. member.name, { sheet = "full", animationDuration = 0.22, id = "marriage-drawer" })
        local children, footer = {}, {}
        if page == "candidates" then
            table.insert(children, Text("托媒访亲", { fontSize = 27 }))
            table.insert(children, Text("先认识人，再商议两家的日子。对象与家资会随年份变化。", { fontColor = C.secondary }))
            local allowed, reason = Marriage.Reason(run, memberId)
            if not allowed then table.insert(children, Card({ Text(reason) })) end
            for _, candidate in ipairs(Marriage.Candidates(run, memberId)) do
                local family = M.Find(run.marriage.households, candidate.householdId)
                local portrait = State.Copy(candidate); portrait.id = M.Hash(candidate.id); Art.Assign(portrait, tostring(run.marriage.seed))
                table.insert(children, Card({
                    UI.Row { gap = 12, alignItems = "center", children = { Visual.Portrait(portrait, { size = 60 }), UI.Panel { flex = 1, minWidth = 0, children = { Text(candidate.name .. " · " .. candidate.age .. "岁", { fontSize = 23 }), Text("天资" .. candidate.talent .. "/5 · " .. Data.FocusNames[candidate.focus] .. candidate.stats[candidate.focus], { fontColor = C.primary }) } } } },
                    Text(candidate.wish, { fontColor = C.primary }),
                    Text(family.history .. "当前希望“" .. family.needText .. "”。"),
                    Text(Identity(family), { fontSize = 13, fontColor = C.secondary }),
                    Text(Data.Place(family.placeId).short .. " · 家资" .. family.assets.money .. "两、" .. family.assets.grain .. "石、" .. family.assets.land .. "亩", { fontSize = 13 }),
                    Button("商议婚约", function()
                        input.candidateId = candidate.id; input.offerId = "plain"
                        input.form = Marriage.Offers(run, candidate.id)[1].forms[1]; Go("terms")
                    end, { id = "marriage-candidate-" .. candidate.id }),
                }))
            end
            if #Marriage.Candidates(run, memberId) == 0 and allowed then table.insert(children, Text("媒人暂未遇到合适对象，下一年会有新的消息。")) end
        elseif page == "terms" or page == "quote" then
            local candidate = M.Find(run.marriage.candidates, input.candidateId)
            local family = M.Find(run.marriage.households, candidate.householdId)
            table.insert(children, Text(member.name .. " 与 " .. candidate.name, { fontSize = 25 }))
            if page == "terms" then
                table.insert(children, Text("两家约定", { fontSize = 20 }))
                for _, offer in ipairs(Marriage.Offers(run, candidate.id)) do
                    table.insert(children, Button(offer.name .. (input.offerId == offer.id and " · 已选" or ""), function()
                        input.offerId = offer.id; if not HasValue(offer.forms, input.form) then input.form = offer.forms[1] end; render()
                    end, { selected = input.offerId == offer.id }))
                    table.insert(children, Text(offer.detail, { fontSize = 13 }))
                end
                local offer = M.Find(Marriage.Offers(run, candidate.id), input.offerId)
                for _, formId in ipairs(offer.forms) do
                    local form = M.Find(M.Forms, formId)
                    table.insert(children, Button(form.name .. (input.form == formId and " · 已选" or ""), function() input.form = formId; render() end, { selected = input.form == formId }))
                    table.insert(children, Text(form.detail, { fontSize = 13 }))
                end
                if input.form == "dual" then
                    table.insert(children, Button("孩子归" .. (input.childHome == "home" and "本家" or "亲家") .. " · 点击更换", function() input.childHome = input.childHome == "home" and "external" or "home"; render() end))
                end
                table.insert(children, Text("成婚礼仪", { fontSize = 20 }))
                for _, wedding in ipairs(M.Weddings) do
                    table.insert(children, Button(wedding.name .. " · " .. wedding.money .. "两 / " .. wedding.grain .. "石" .. (input.weddingId == wedding.id and " · 已选" or ""), function() input.weddingId = wedding.id; render() end, { selected = input.weddingId == wedding.id }))
                end
                table.insert(children, Button("资助受惠人 · " .. (input.aidTargetId and Name(run, input.aidTargetId) or (input.form == "in" and candidate.name or input.form == "out" and Name(run, run.leaderId) or member.name)), function()
                    chooser = { title = "由谁承接亲家资助", back = "terms", select = function(id) input.aidTargetId = id; Go("terms") end }
                    Go("choose")
                end))
            end
            local quote, reason = Marriage.Quote(run, memberId, input)
            if quote then
                local costs = quote.costs
                table.insert(children, Card({ Text("婚约账目", { fontSize = 23 }),
                    Text("支出 " .. quote.moneyCost .. "两、" .. quote.grainCost .. "石", { fontSize = 22, fontColor = C.primary }),
                    Text("媒礼" .. costs.media .. " · 仪礼" .. costs.wedding .. " · " .. (input.form == "out" and "妆资" or "聘资") .. costs.transfer .. " · 安置" .. costs.housing .. " · 路费" .. costs.route, { fontSize = 13 }),
                    Text("匹配减免" .. quote.discount .. "两 · 守约减免" .. quote.rebate .. "两", { fontSize = 13 }),
                    Text("亲家相赠 " .. quote.giftMoney .. "两 / " .. quote.giftGrain .. "石；本人成婚礼金 " .. quote.weddingGift .. "两、声望+" .. quote.reputation),
                    Text("办妥后余 " .. quote.money .. "两、" .. quote.grain .. "石 · 迁入" .. quote.incoming .. "人 / 迁出" .. quote.outgoing .. "人", { fontColor = C.primary }),
                }))
                for _, duty in ipairs(quote.duties) do table.insert(children, Card({ Text(duty.name, { fontSize = 19 }), Text(DutyText(duty)) })) end
                table.insert(children, Card({ Text("亲家与后续", { fontSize = 20 }), Text(Identity(family)), Text(AidText(quote.aid)), Text(M.Projects[family.patron.role].detail, { fontSize = 13 }), Text("办理费用另付，需选人安排实际工作，并占用其一项额外事务。", { fontSize = 13, fontColor = C.secondary }) }))
                if quote.object then
                    local heritage = quote.object.kind == "trait" and M.Traits[quote.object.traitId].detail or quote.object.kind == "book" and "获得唯一旧书，实际读书学识+2，共3次，余次可由后代接手。" or M.Projects.artisan.detail
                    table.insert(children, Card({ Text("家法与传承", { fontSize = 20 }), Text(heritage), Text(quote.object.kind == "trait" and ("家法由" .. candidate.name .. "持有，需在家配合实际安排生效。") or "物件可由在家族人接手，保留剩余用途。", { fontSize = 13, fontColor = C.secondary }) }))
                end
                if page == "quote" and quote.affordable then
                    local future = State.Copy(run)
                    assert(Marriage.Marry(future, memberId, input))
                    local ledger = Economy.Preview(future)
                    table.insert(children, Card({ Text("按当前安排预估下一年", { fontSize = 20 }), Text("年末预计余银" .. ledger.money .. "两、余粮" .. ledger.grain .. "石；生活费" .. ledger.livingExpense .. "两、口粮" .. ledger.foodNeed .. "石。"), Text("新入户成员默认料理家事。具体收益按当年实际安排结算。", { fontSize = 13 }) }))
                end
                if not quote.affordable then table.insert(children, Text("钱粮需足额支付支出，并在礼成后留有余粮。", { fontColor = C.danger })) end
                table.insert(footer, Button(page == "terms" and "核对婚约" or "照约成婚并入谱", function()
                    if page == "terms" then Go("quote")
                    else Act(function(current) return Marriage.Marry(current, memberId, input) end) end
                end, { id = page == "terms" and "marriage-review" or "marriage-confirm", role = "primary", disabled = not quote.affordable }))
            else table.insert(children, Text(reason, { fontColor = C.danger })) end
            sheet:SetBack(function() Go(page == "terms" and "candidates" or "terms") end)
        elseif page == "choose" then
            table.insert(children, Text(chooser.title, { fontSize = 23 }))
            for _, person in ipairs(run.members) do
                if person.alive and State.IsResident(person) then
                    local ok, reason = true, ""
                    if chooser.reason then ok, reason = chooser.reason(run, person.id) end
                    table.insert(children, Card({ Text(person.name .. " · " .. person.age .. "岁 · " .. Data.Jobs[person.jobId].name, { fontSize = 19 }), Text(ok and "符合条件" or reason, { fontSize = 13 }), Button("交给" .. person.name, function()
                        if chooser.select then chooser.select(person.id) else Act(function(current) return chooser.action(current, person.id) end) end
                    end, { disabled = not ok }) }))
                end
            end
            sheet:SetBack(function() Go(chooser.back) end)
        elseif page == "heritage" then
            table.insert(children, Text("家法与传承", { fontSize = 26 })); Heritage(run, children)
            sheet:SetBack(function() Go("family") end)
        else
            table.insert(children, Text("婚约与亲家", { fontSize = 26 })); ContractCards(run, children); Affairs(run, children)
            if Marriage.Reason(run, memberId) then table.insert(children, Button("托媒访亲", function() Go("candidates") end)) end
            table.insert(footer, Button("家法与物件传承", function() Go("heritage") end))
        end
        sheet:AddContent(ModalLayout.Scroll(UI.Panel { width = "100%", gap = 12, paddingBottom = 12, children = children }, { id = "marriage-scroll" }))
        local footerCells = {}
        for _, button in ipairs(footer) do table.insert(footerCells, UI.Panel { flex = 1, minWidth = 0, children = { button } }) end
        if #footerCells > 0 then sheet:SetFooter(UI.Row { gap = 8, children = footerCells }) end
        sheet:Open()
        return sheet
    end
    return render()
end

return MarriageView
