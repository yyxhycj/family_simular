local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"

local MemberView = {}

local C = V7.Colors

local function Text(value, props)
    props = props or {}
    props.fontSize = math.max(15, props.fontSize or V7.Tokens.body)
    return Visual.Text(value, props)
end

local function Button(value, onClick, props)
    props = props or {}
    props.height = math.max(44, props.height or V7.Tokens.buttonHeight)
    props.fontSize = math.max(15, props.fontSize or V7.Tokens.buttonText)
    props.role = props.role or (props.selected and "primary" or "secondary")
    return Visual.Button(value, onClick, props)
end

local function Card(children, props)
    return Visual.Card(children, props)
end

local function TableValue(value)
    return type(value) == "table" and value or {}
end

local function MemberNames(run, memberIds)
    local names = {}
    for _, memberId in ipairs(memberIds or {}) do
        local member = State.FindMember(run.members, memberId)
        if member then table.insert(names, member.name) end
    end
    return #names > 0 and table.concat(names, "、") or "未记录"
end

local function FactMap(run)
    local result = {}
    for _, fact in ipairs(run.facts or {}) do result[fact.id] = fact end
    return result
end

local function BuildTabs(section, setSection)
    local items = {
        { id = "overview", text = "概况" },
        { id = "arrangement", text = "安排" },
        { id = "life", text = "经历" },
    }
    local buttons = {}
    for _, item in ipairs(items) do
        local selected = section == item.id
        table.insert(buttons, Button(item.text, function() setSection(item.id) end, {
            flex = 1, height = 44, selected = selected, role = selected and "primary" or "secondary",
        }))
    end
    return UI.Row { gap = 6, children = buttons }
end

local function BuildStats(member)
    local stats = TableValue(member.stats)
    local values = {
        { "学识", stats.learn or 0 }, { "手艺", stats.skill or 0 },
        { "医术", stats.medicine or 0 }, { "经营", stats.trade or 0 },
        { "武艺", stats.martial or 0 }, { "体魄", member.health or 0 },
    }
    local cards = {}
    for _, item in ipairs(values) do
        table.insert(cards, UI.Panel {
            minHeight = 68, padding = 9, gap = 3,
            backgroundColor = C.paperLight, borderWidth = 1, borderColor = C.rule,
            children = {
                Text(item[1], { fontSize = 13, fontColor = C.secondary }),
                Text(tostring(item[2]) .. "/100", { fontSize = 21, fontWeight = "bold" }),
            },
        })
    end
    return UI.Panel {
        borderWidth = 1, borderColor = C.rule, overflow = "hidden",
        children = { UI.SimpleGrid { columns = 2, gap = 0, children = cards } },
    }
end

local function BuildIdentity(app, member)
    local run = app.run
    local talent = Data.Talent(math.tointeger(member.talent) or 1)
    local experience = Data.Experience(member.experienceId)
    local generation = State.Generation(run.members, member.id)
    local status = member.alive and "在世" or "已故 · 生平可读"
    return UI.Panel {
        gap = 10,
        children = {
            UI.Row {
                gap = 14, alignItems = "center",
                children = {
                    Visual.Portrait(member, {
                        size = 90, detail = true, deceased = not member.alive,
                        sick = member.alive and (member.health or 0) < 35,
                        leader = member.id == run.leaderId,
                    }),
                    UI.Panel {
                        flex = 1, minWidth = 0, gap = 4,
                        children = {
                            Text(member.name, { fontSize = 25, fontWeight = "bold" }),
                            Text(member.sex .. " · " .. tostring(member.age) .. " 岁 · 第 " .. tostring(generation) .. " 代", { fontSize = 15, fontColor = C.secondary }),
                            Text(status, { fontSize = 14, fontColor = member.alive and C.primary or C.secondary }),
                            Text(talent.name .. "资质 " .. tostring(member.talent or 1) .. "/5 · " .. (experience and experience.name or "尚未专精"), {
                                fontSize = 13, fontColor = C.ink, backgroundColor = C.selected,
                                borderWidth = 1, borderColor = C.rule, paddingHorizontal = 7, paddingVertical = 5,
                            }),
                        },
                    },
                },
            },
        },
    }
end

local function BuildOverview(app, member, openArrangement)
    local run = app.run
    local spouse = member.spouseId and State.FindMember(run.members, member.spouseId)
    local currentJob = Data.Jobs[member.jobId]
    local experience = Data.Experience(member.experienceId)
    return UI.Panel {
        gap = 12,
        children = {
            Card({
                Text(experience and experience.name or "眼前的本领", { fontSize = 18, fontWeight = "bold" }),
                Text("资质决定起点，当前属性与年度安排分别记录在家谱中。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.45 }),
            }, { backgroundColor = C.selected }),
            Text("当前属性", { fontSize = 18, fontWeight = "bold" }),
            BuildStats(member),
            Card({
                UI.Row { justifyContent = "space-between", children = {
                    Text("父母 / 养亲", { fontSize = 14, fontColor = C.secondary }),
                    Text(MemberNames(run, member.parents), { fontSize = 15, fontWeight = "bold" }),
                } },
                UI.Row { justifyContent = "space-between", children = {
                    Text("配偶", { fontSize = 14, fontColor = C.secondary }),
                    Text(spouse and spouse.name or "未婚", { fontSize = 15, fontWeight = "bold" }),
                } },
            }, { gap = 11 }),
            Card({
                Text("性格与本领", { fontSize = 18, fontWeight = "bold" }),
                Text("性格：" .. tostring(member.trait or "未记录") .. " · 经历：" .. (experience and experience.name or "尚未专精"), { fontSize = 15, fontColor = C.secondary, whiteSpace = "normal" }),
            }, { backgroundColor = C.selected }),
            Card({
                Text(member.alive and (currentJob and currentJob.name or "未安排") or "生平已封存", { fontSize = 18, fontWeight = "bold" }),
                Text(member.alive and (currentJob and currentJob.desc or "当前没有可显示的安排。") or "关系、事实和人生记录仍可查阅。", {
                    fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.45,
                }),
                member.alive and not run.ending and Button("调整安排", openArrangement, { height = 44, role = "secondary" }) or Text(run.ending and "本局已落笔，安排已封存。" or "已故成员不再安排新的主业。", { fontSize = 13, fontColor = C.secondary }),
            }),
        },
    }
end

local function BuildArrangement(app, member, modal)
    local run = app.run
    if not member.alive or run.ending then
        return UI.Panel {
            gap = 12,
            children = {
                Card({
                    Text("当前无法调整安排", { fontSize = 20, fontWeight = "bold" }),
                    Text(run.ending and "本局已落笔，人物经历与关系均可阅读。" or "这位族人的生平已经封存。", { fontSize = 15, fontColor = C.secondary, whiteSpace = "normal" }),
                }),
            },
        }
    end

    local ageRules = Data.AgeRules
    local stage, stageDetail
    if member.age < ageRules.study then
        stage, stageDetail = "幼年", "当前可安排随家人生活或休养；" .. tostring(ageRules.study) .. " 岁起可读书。"
    elseif member.age < ageRules.training then
        stage, stageDetail = "启蒙", "可读书求学；" .. tostring(ageRules.training) .. " 岁起可学艺、学医或习武。"
    elseif not State.IsAdult(member) then
        stage, stageDetail = "少年", "可读书、学艺、学医或习武；" .. tostring(ageRules.adult) .. " 岁起可承担家事与家业。"
    else
        stage, stageDetail = "成年", "可承担家业与家事；具体资格和费用会在确认前核对。"
    end

    local children = {
        Text("目前的安排", { fontSize = 19, fontWeight = "bold" }),
        Card({ Text(stage .. " · " .. tostring(member.age) .. " 岁", { fontSize = 18, fontWeight = "bold" }), Text(stageDetail, { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.45 }) }, { backgroundColor = C.selected }),
        Text("选择新的安排", { fontSize = 18, fontWeight = "bold" }),
        Text("确认后写入家史；资格、收入或培养费用会在操作前显示。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal" }),
    }

    for _, jobId in ipairs(Data.JobOrder) do
        local job = Data.Jobs[jobId]
        if job and member.age >= job.min then
            local ok, reason = Simulation.GetJobReason(member, jobId)
            local selected = member.jobId == jobId
            table.insert(children, Button(job.name .. (ok and "" or " · " .. reason), function()
                if ok then app:ConfirmRunJob(member.id, jobId, modal) end
            end, {
                height = 46, disabled = not ok, textAlign = "left", paddingHorizontal = 12,
                selected = selected, role = selected and "primary" or "secondary",
            }))
        end
    end

    if State.IsAdult(member) then
        table.insert(children, Button("应试（10 两）", function()
            app:ConfirmRunAction("确认应试 · " .. member.name, "成本：10 两盘缠。结果由本人的学识与本局随机结果共同决定，并完整写入人生经历。", function()
                return Simulation.TakeExam(app.run, member.id)
            end, "确认应试", modal)
        end, { height = 46, role = "primary" }))
        table.insert(children, Button("安排婚配（12 两）", function()
            app:ConfirmRunAction("确认婚配 · " .. member.name, "成本：12 两安置费。结果：新配偶加入家谱，原有族人资料保持不变。", function()
                return Simulation.Marry(app.run, member.id)
            end, "确认婚配", modal)
        end, { height = 46 }))
        table.insert(children, Button("收养孩子（8 两）", function()
            app:ConfirmRunAction("确认收养 · " .. member.name, "成本：8 两安置费。结果：孩子加入家谱，拥有与其他族人同等的成长与继任资格。", function()
                return Simulation.Adopt(app.run, member.id)
            end, "确认收养", modal)
        end, { height = 46 }))

        local canPlanBirth, birthReason = State.CanPlanBirth(member)
        if canPlanBirth then
            table.insert(children, Button(member.birthPlan == false and "愿意迎接孩子" or "暂缓迎接孩子", function()
                local nextPlan = member.birthPlan == false
                app:ConfirmRunAction("确认添丁计划 · " .. member.name, nextPlan and "结果：记录为愿意迎接孩子；是否添丁仍由后续年度的真实家庭条件决定。" or "结果：记录为暂缓计划，当前族人其他资料保持不变。", function()
                    return Simulation.SetBirthPlan(app.run, member.id, nextPlan)
                end, "确认记录", modal)
            end, { height = 46 }))
        else
            table.insert(children, Text("添丁计划：" .. birthReason, { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal" }))
        end

        table.insert(children, Button("任命为族长", function()
            app:ConfirmRunAction("确认交接 · " .. member.name, "结果：开始新的族长任期，现有安排与资产保持原样。", function()
                return Simulation.AppointLeader(app.run, member.id, "主动交接")
            end, "确认交接", modal)
        end, { height = 46 }))

        for _, relic in ipairs(app.run.relicInstances or {}) do
            if relic.status ~= "sold" and relic.custodianId ~= member.id then
                local definition = Data.Relic(relic.definitionId)
                if definition then
                    table.insert(children, Button("交由" .. member.name .. "保管 · " .. definition.name, function()
                        app:ConfirmRunAction("确认更换保管人", "物件：" .. definition.name .. "\n结果：保管人改为" .. member.name .. "，当前调查进度保持不变。", function()
                            return Simulation.TransferRelic(app.run, relic.instanceId, member.id)
                        end, "确认托付", modal)
                    end, { height = 44, fontSize = 13 }))
                end
            end
        end
    end

    return UI.Panel { gap = 11, children = children }
end

local function BuildLife(app, member, page, setPage)
    local entries = {}
    local factMap = FactMap(app.run)
    for _, line in ipairs(member.biography or {}) do
        table.insert(entries, { kind = "生平", text = line })
    end
    for _, factId in ipairs(member.factIds or {}) do
        local fact = factMap[factId]
        if fact then table.insert(entries, { kind = "事实", year = fact.year, text = fact.text }) end
    end

    local pageSize = 5
    local pageCount = math.max(1, math.ceil(#entries / pageSize))
    page = math.max(1, math.min(page, pageCount))
    local children = {
        Text("生活与经历", { fontSize = 19, fontWeight = "bold" }),
        Text("人物生平与事实记录完整保留，按页阅读。", { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal" }),
    }
    local first = (page - 1) * pageSize + 1
    local last = math.min(page * pageSize, #entries)
    for index = first, last do
        local entry = entries[index]
        local title = entry.kind .. (entry.year and (" · 大晟历 " .. tostring(entry.year) .. " 年") or "")
        table.insert(children, Card({
            Text(title, { fontSize = 13, fontColor = C.secondary }),
            Text(entry.text, { fontSize = 16, whiteSpace = "normal", lineHeight = 1.5 }),
        }, { padding = 11 }))
    end
    if #entries == 0 then table.insert(children, Card({ Text("尚无可回看的经历。", { fontSize = 16, fontColor = C.secondary }) })) end

    table.insert(children, UI.Row { gap = 6, children = {
        Button("上一页", function() setPage(page - 1) end, { flex = 1, disabled = page <= 1 }),
        Text(tostring(page) .. " / " .. tostring(pageCount), { flex = 1, textAlign = "center", fontSize = 14, fontColor = C.secondary }),
        Button("下一页", function() setPage(page + 1) end, { flex = 1, disabled = page >= pageCount }),
    } })
    return UI.Panel { gap = 11, children = children }
end

function MemberView.Open(app, memberId)
    local member = State.FindMember(app.run.members, memberId)
    if not member then return end

    app.memberLifePages = app.memberLifePages or {}
    local lifePage = app.memberLifePages[memberId] or 1
    local section = "overview"
    local body = UI.Panel { gap = 11, children = {} }
    local viewHeight = math.max(100, UI.GetHeight() * 0.9 - 184)
    local scroll = UI.ScrollView { height = viewHeight, padding = 14, children = { body } }
    local paper = Visual.Paper({ scroll }, { padding = 5 })
    local modal = UI.Modal {
        title = "一个人的一生", size = "fullscreen", backgroundColor = C.paper,
        contentBgColor = C.paper, borderColor = C.rule, titleTextColor = C.ink,
        closeIconColor = C.secondary, closeOnOverlay = true,
        onClose = function(selfModal) selfModal:Destroy() end,
    }

    local render
    local function setSection(nextSection)
        section = nextSection
        render()
    end
    local function setLifePage(nextPage)
        app.memberLifePages[memberId] = nextPage
        lifePage = nextPage
        render()
    end
    render = function()
        body:ClearChildren()
        body:AddChild(BuildIdentity(app, member))
        body:AddChild(BuildTabs(section, setSection))
        if section == "overview" then
            body:AddChild(BuildOverview(app, member, function() setSection("arrangement") end))
        elseif section == "arrangement" then
            body:AddChild(BuildArrangement(app, member, modal))
        else
            body:AddChild(BuildLife(app, member, lifePage, setLifePage))
        end
    end

    modal:AddContent(paper)
    modal:SetFooter(Button("返回家谱", function() modal:Close() end, { width = "100%", height = 48, role = "primary" }))
    render()
    modal:Open()
end

return MemberView
