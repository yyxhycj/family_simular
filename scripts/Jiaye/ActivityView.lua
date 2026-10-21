local UI = require "urhox-libs/UI"
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Visual = require "Jiaye.Visual"
local V7 = require "Jiaye.V7"
local ModalLayout = require "Jiaye.ModalLayout"
local MarriageView = require "Jiaye.MarriageView"
local EventView = require "Jiaye.EventView"
local LedgerView = require "Jiaye.LedgerView"
local AchievementsView = require "Jiaye.AchievementsView"
local AchievementDefinitions = require "Jiaye.AchievementDefinitions"

local ActivityView = {}
local C = V7.Colors
local PAGE_SIZE = 20
local Jobs = {
    play = "随家人生活", study = "读书", farm = "耕作", apprentice = "学艺", craft = "做工", trade = "经商",
    teach = "教书", medical = "学医", doctor = "行医", train = "习武", guard = "护卫", official = "任职", home = "持家", rest = "休养",
}
local Important = { breakthrough = true, exam = true, birth = true, death = true, marriage = true,
    adoption = true, leadership = true, migration = true, ending = true, achievement = true, annual_ledger = true }

local function Context(run)
    local result = { facts = {}, ledgers = {}, events = {}, stories = {}, tasks = {}, contracts = {}, projects = {}, instances = {}, entries = {} }
    local positions = {}
    for index, entry in ipairs(run.logs) do
        table.insert(result.entries, entry)
        positions[entry] = index
    end
    table.sort(result.entries, function(left, right)
        if left.year ~= right.year then return left.year > right.year end
        return positions[left] < positions[right]
    end)
    for _, fact in ipairs(run.facts) do result.facts[fact.id] = fact end
    for _, ledger in ipairs(run.annualLedgers) do result.ledgers[ledger.id] = ledger end
    for _, event in ipairs(run.events) do result.events[event.instanceId] = event end
    for _, story in ipairs(run.marriage.stories) do result.stories[story.id] = story end
    for _, task in ipairs(run.relicTasks or {}) do result.tasks[task.id] = task end
    for _, instance in ipairs(run.relicInstances) do result.instances[instance.instanceId] = instance end
    for _, contract in ipairs(run.marriage.contracts) do result.contracts[contract.id] = contract end
    for _, project in ipairs(run.marriage.projects) do result.projects[project.id] = project end
    return result
end

local function Signed(value)
    return (value >= 0 and "+" or "") .. tostring(value)
end

local function Message(run, entry, context)
    local fact = context.facts[entry.factId] or entry
    local kind = entry.kind or fact.kind
    local ids = entry.memberIds or fact.memberIds or {}
    local member = State.FindMember(run.members, ids[1])
    local name = member and member.name or ""
    local event = context.events[entry.eventId]
    local story = context.stories[entry.storyId]
    local text = entry.text:gsub("。$", "")
    local warning = kind == "death" or kind == "exam" and fact.passed == false
    local important = Important[kind] == true
    if kind == "annual_progress" then
        local ledger = assert(context.ledgers[entry.ledgerId], "年度动态缺少账本。")
        for _, row in ipairs(ledger.members) do
            if row.memberId == ids[1] then
                local job = assert(Jobs[row.jobId])
                warning = not row.executed
                text = row.name .. job
                if row.executed then
                    local results = {}
                    local growth = row.growth
                    local amount = growth.stat == "health" and growth.health or growth.amount
                    if growth.stat and amount ~= 0 then
                        table.insert(results, (growth.stat == "health" and "体魄" or assert(Data.FocusNames[growth.stat])) .. Signed(amount))
                    end
                    if row.money ~= 0 then table.insert(results, "银" .. Signed(row.money) .. "两") end
                    if row.grain ~= 0 then table.insert(results, "粮" .. Signed(row.grain) .. "石") end
                    if #results > 0 then text = text .. "，" .. table.concat(results, "、") end
                else
                    text = text .. "未成：" .. (row.requiredPayment > 0 and "培养费不足" or "条件未满足")
                end
                break
            end
        end
    elseif kind == "annual_ledger" then
        local ledger = assert(context.ledgers[entry.ledgerId or fact.ledgerId])
        text = "全年银" .. Signed(ledger.netMoney) .. "两，粮" .. Signed(ledger.netGrain) .. "石"
    elseif event then
        text = event.title
        if event.type == "growth" then
            text = name .. (event.growthId == "promotion" and "出师，可" .. Data.Jobs[event.jobId].name or "成年")
        elseif event.status == "pending" then text = text .. "（待定）" end
        important = true
    elseif story then
        text = story.title .. (story.status == "pending" and "（待定）" or "")
        important = true
    elseif kind == "growth" then
        if fact.growthId == "promotion" then
            text = name .. (fact.choice == "defer" and "暂缓出师" or "可" .. Data.Jobs[fact.jobId].name)
            important = fact.choice ~= "defer"
        else text = name .. (fact.choice == "defer" and "暂缓安排" or "成年") end
    elseif kind == "job" and fact.toJobId then text = name .. "改为" .. assert(Jobs[fact.toJobId])
    elseif kind == "exam" then text = name .. (fact.passed and "应试得中" or "应试未中")
    elseif kind == "death" then text = name .. "离世"
    elseif kind == "birth" then text = assert(State.FindMember(run.members, ids[#ids])).name .. "出生"
    elseif kind == "marriage" then text = name .. "与" .. assert(State.FindMember(run.members, ids[2])).name .. "成婚"
    elseif kind == "leadership" then text = assert(State.FindMember(run.members, ids[#ids])).name .. "接任族长"
    elseif kind == "migration" and fact.placeId then text = "迁居" .. Data.Place(fact.placeId).short
    elseif kind == "ending" then text = run.ending.title; warning = run.ending.automatic == true
    elseif kind == "achievement" then text = text:gsub("^达成成就“", "成就「"):gsub("”$", "」")
    elseif kind == "relic" then
        text = text:gsub("^信物行动已受理：", "接下")
        important = fact.taskStatus == "settled"
    elseif kind == "task_progress" then
        local task, progress = text:match("^(“.-”).-已完成 (%d+/%d+) 年")
        warning = text:find("本年进度未增加", 1, true) ~= nil or text:find("暂时停下", 1, true) ~= nil
        if task then text = task .. " " .. progress .. "年" .. (warning and "（停滞）" or "")
        else text = text:gsub("暂时停下：.*$", "暂停") end
    elseif kind == "event" then text = text:gsub("：需要你的决定$", "（待定）")
    end
    return text, warning and C.danger or C.ink, important or warning
end

local function Destination(app, entry, context)
    local fact = context.facts[entry.factId] or entry
    local kind = entry.kind or fact.kind
    local ids = entry.memberIds or fact.memberIds or {}
    local event, story = context.events[entry.eventId], context.stories[entry.storyId or fact.storyId]
    if event and event.status == "pending" then return function() EventView.Open(app, event) end end
    local ledgerId = entry.ledgerId or fact.ledgerId
    if kind == "annual_ledger" and context.ledgers[ledgerId] then
        return function() LedgerView.Open(app, ledgerId) end
    end
    if kind == "achievement" then
        local achievementId = entry.achievementId
        if not achievementId then
            for id, definition in pairs(AchievementDefinitions.ById) do
                if entry.text == "达成成就“" .. definition.name .. "”。" then achievementId = id; break end
            end
        end
        if achievementId and app.profile.achievements[achievementId] then
            return function() AchievementsView.OpenDetail(app, achievementId) end
        end
    end
    local task = context.tasks[entry.taskId or fact.taskId]
    local instanceId = task and task.instanceId or fact.relicInstanceId or fact.instanceId
    if context.instances[instanceId] then
        local tab = task and (task.status == "active" or task.status:find("paused", 1, true) == 1 or task.status == "ready") and "growth" or "history"
        return function() app:OpenRelic(instanceId, tab) end
    end
    local project = context.projects[entry.projectId or fact.projectId]
    local contract = context.contracts[entry.contractId or fact.contractId or (story and story.contractId) or (project and project.contractId)]
    if contract then return function() MarriageView.Open(app, contract.memberId, "family") end end
    if entry.lessonId or fact.lessonId then return function() MarriageView.Open(app, ids[1], "heritage") end end
    local memberId = ids[(kind == "birth" or kind == "adoption" or kind == "leadership") and #ids or 1]
    local member = State.FindMember(app.run.members, memberId)
    if member then return function() app:OpenRunMember(member.id) end end
end

local function BuildEntry(app, entry, context, modal, id)
    local text, color, bold = Message(app.run, entry, context)
    local destination = Destination(app, entry, context)
    local function open()
        if modal then modal:Close() end
        destination()
    end
    local children = { Visual.Text(text, { id = id or "activity-text-" .. entry.id, flex = 1, minWidth = 0, fontSize = 15,
        whiteSpace = "normal", lineHeight = 1.4, fontColor = color, fontWeight = bold and "bold" or "normal" }) }
    if destination then table.insert(children, Visual.Text("›", { width = 12, fontSize = 16, textAlign = "right", fontColor = C.secondary })) end
    return UI.Panel { id = id and (id .. "-row") or "activity-entry-" .. entry.id, width = "100%",
        minHeight = modal and 36 or 28, paddingVertical = modal and 5 or 2, flexDirection = "row", gap = 6,
        borderWidth = 0, borderRadius = 0, backgroundColor = false, alignItems = "center",
        pointerEvents = destination and "box-only" or "none", onClick = destination and open or nil, children = children }
end

local function BuildRows(app, first, last, context, modal)
    local children = {}
    ---@type number?
    local year = nil
    for index = first, last do
        local entry = context.entries[index]
        if entry.year ~= year then
            year = entry.year
            table.insert(children, UI.Row { id = (modal and "activity-year-" or "activity-preview-year-") .. year, width = "100%", gap = 10, paddingVertical = 7,
                alignItems = "center", borderRadius = 0, children = {
                    Visual.Text("大晟历 " .. year .. " 年", { fontSize = 13, fontColor = C.secondary }),
                    UI.Panel { flex = 1, height = 1, borderRadius = 0, backgroundColor = C.rule },
                } })
        end
        table.insert(children, BuildEntry(app, entry, context, modal, not modal and "activity-preview-" .. index or nil))
    end
    if #children == 0 then table.insert(children, Visual.Text("家谱新启，静候新事。", { fontSize = 15, fontColor = C.secondary })) end
    return UI.Panel { width = "100%", borderRadius = 0, children = children }
end

function ActivityView.Open(app)
    local entries = app.run.logs
    local context = Context(app.run)
    local page, pages = 1, math.max(1, math.ceil(#entries / PAGE_SIZE))
    local modal = ModalLayout.New("家族动态", { id = "activity-detail", sheet = "full", closeOnOverlay = true })
    local function show(nextPage)
        page = nextPage
        modal:AddContent(UI.Panel { id = "activity-content", width = "100%", flexGrow = 1, flexBasis = 0, minHeight = 0,
            gap = 8, children = {
                ModalLayout.Scroll(BuildRows(app, (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #entries), context, modal), { id = "activity-scroll" }),
                UI.Row { width = "100%", gap = 6, alignItems = "center", children = {
                    Visual.Button("最新", function() show(1) end, { id = "activity-latest", flex = 1, height = 44, paddingHorizontal = 4, role = "secondary", disabled = page == 1 }),
                    Visual.Button("上一页", function() show(page - 1) end, { id = "activity-prev", flex = 1, height = 44, paddingHorizontal = 4, role = "secondary", disabled = page == 1 }),
                    Visual.Text(tostring(page) .. "/" .. tostring(pages), { id = "activity-page", width = 48, fontSize = 14, textAlign = "center" }),
                    Visual.Button("下一页", function() show(page + 1) end, { id = "activity-next", flex = 1, height = 44, paddingHorizontal = 4, role = "secondary", disabled = page == pages }),
                } },
            } })
    end
    show(1)
    modal:Open()
end

function ActivityView.Bar(app)
    local entries = app.run.logs
    local children = {
        UI.Row { id = "activity-expand", width = "100%", minHeight = 28, alignItems = "center", pointerEvents = "box-only",
            onClick = function() ActivityView.Open(app) end, children = {
            Visual.Text("家族动态", { fontSize = 15, fontWeight = "bold", fontColor = C.primary }),
            UI.Panel { flex = 1 },
            Visual.Text("展开  ›", { fontSize = 12, fontColor = C.secondary }),
        } },
    }
    table.insert(children, BuildRows(app, 1, math.min(2, #entries), Context(app.run)))
    return UI.Panel { id = "activity-bar", width = "100%", minHeight = 60, flexShrink = 0, padding = { 7, 14 },
        backgroundColor = C.paperLight, borderWidth = 0, borderRadius = 0, pointerEvents = "box-none", children = children }
end

return ActivityView
