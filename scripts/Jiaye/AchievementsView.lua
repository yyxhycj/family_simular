local UI = require "urhox-libs/UI"
local Visual = require "Jiaye.Visual"
local V7 = require "Jiaye.V7"
local ModalLayout = require "Jiaye.ModalLayout"
local Achievements = require "Jiaye.Achievements"
local Definitions = require "Jiaye.AchievementDefinitions"

local View = {}
local C = V7.Colors

function View.Open(app)
    if app.unsaved then app:Notify("请先保存当前安排，再查看成就。", "warning"); return end
    local visible = Achievements.Visible(app.profile)
    local progress = Achievements.Progress(app.profile, app.run)
    local completed, total = 0, 0
    for _, definition in ipairs(visible) do
        if not definition.hidden then
            total = total + 1
            if app.profile.achievements[definition.id] then completed = completed + 1 end
        end
    end
    ---@type Label?
    local platformStatus = nil
    local modal = ModalLayout.New("成就 · 家史留名", { sheet = "full", onClose = function()
        if app.tapAchievementStatusLabel == platformStatus then app.tapAchievementStatusLabel = nil end
    end })
    local body = UI.Panel { id = "achievements", width = "100%", height = "100%", minHeight = 0, gap = 10 }
    local group, status, page = "all", "all", 1
    local options = { { value = "all", label = "全部类别" } }
    for _, name in ipairs(Definitions.Groups) do
        local present = false
        for _, definition in ipairs(visible) do if definition.group == name then present = true; break end end
        if present then table.insert(options, { value = name, label = name }) end
    end
    local function Render()
        body:RemoveAllChildren()
        app.tapAchievementStatusLabel = nil
        body:AddChild(Visual.Text("已记 " .. completed .. " / " .. total .. " 项", { id = "achievements-summary", fontSize = 22, fontFamily = "serif", fontColor = C.primary }))
        platformStatus = Visual.Text(app:TapAchievementStatus(), { id = "achievements-platform-status", fontSize = 12, fontColor = C.secondary, whiteSpace = "normal" })
        app.tapAchievementStatusLabel = platformStatus
        body:AddChild(platformStatus)
        body:AddChild(UI.Row { width = "100%", gap = 8, children = {
            Visual.Button("成就记录", function()
                if not app.tapAchievements or not app.tapAchievements:Show() then app:Notify(app:TapAchievementStatus(), "warning") end
            end, { id = "achievements-platform-open", flex = 1, minWidth = 0, height = 36, role = "secondary" }),
            Visual.Button("重试同步", function()
                if app.tapAchievements then app.tapAchievements:Retry() else app:Notify(app:TapAchievementStatus(), "warning") end
            end, { id = "achievements-platform-retry", width = 96, height = 36, role = "secondary" }),
        } })
        body:AddChild(UI.Dropdown { id = "achievements-group", width = "100%", height = 42, options = options, value = group,
            onChange = function(_, value) group, page = value, 1; Render() end })
        local tabs = {}
        for _, option in ipairs({ { "all", "全部" }, { "progress", "进行中" }, { "done", "已达成" } }) do
            local value, label = option[1], option[2]
            tabs[#tabs + 1] = Visual.Button(label, function() status, page = value, 1; Render() end,
                { id = "achievements-filter-" .. value, flex = 1, minWidth = 0, height = 40, selected = status == value, role = status == value and "primary" or "secondary" })
        end
        body:AddChild(UI.Row { width = "100%", gap = 6, children = tabs })
        local filtered = {}
        for _, definition in ipairs(visible) do
            local done = app.profile.achievements[definition.id] ~= nil
            if (group == "all" or group == definition.group) and (status == "all" or status == "done" and done or status == "progress" and not done) then
                table.insert(filtered, definition)
            end
        end
        local pages = math.max(1, math.ceil(#filtered / 10))
        page = math.min(page, pages)
        ---@type Widget[]
        local cards = {}
        for index = (page - 1) * 10 + 1, math.min(page * 10, #filtered) do
            local definition = filtered[index]
            local record = app.profile.achievements[definition.id]
            local current = progress[definition.index] or { current = 0, target = 1 }
            local children = {
                UI.Row { gap = 8, alignItems = "center", children = {
                    Visual.Text(definition.name, { flex = 1, minWidth = 0, fontSize = 19, fontFamily = "serif", whiteSpace = "normal" }),
                    Visual.Text(record and "已记" or (math.min(current.current, current.target) .. " / " .. current.target), { fontSize = 13, fontColor = record and C.primary or C.secondary }),
                } },
                Visual.Text(definition.condition, { fontSize = 14, fontColor = C.secondary, whiteSpace = "normal", lineHeight = 1.5 }),
            }
            if record then
                local recorded = record.family .. "家 · 经营第" .. record.yearIndex .. "年" .. (record.legacyBackfill and " · 旧档补记" or "")
                children[#children + 1] = Visual.Text(recorded, { fontSize = 12, fontColor = C.primary, whiteSpace = "normal" })
                children[#children + 1] = Visual.Button("查看达成依据", function()
                    local detail = ModalLayout.New(definition.name, { sheet = "detail" })
                    local evidence = record.evidence
                    local lines = { definition.condition, recorded }
                    if evidence.memberNames and #evidence.memberNames > 0 then lines[#lines + 1] = "参与族人：" .. table.concat(evidence.memberNames, "、") end
                    if evidence.nodes then lines[#lines + 1] = "已完成实际决策节点：" .. #evidence.nodes end
                    for _, text in ipairs(evidence.descriptions or {}) do lines[#lines + 1] = text end
                    if evidence.values and evidence.values.current then lines[#lines + 1] = "达成时记录：" .. evidence.values.current .. " / " .. evidence.values.target end
                    if evidence.values and evidence.values.branch then lines[#lines + 1] = "实际去向：" .. (evidence.values.branch == "public" and "刊行" or evidence.values.branch == "private" and "家传" or evidence.values.branch == "heirloom" and "合璧" or "各执") end
                    detail:AddContent(ModalLayout.Scroll(Visual.Text(table.concat(lines, "\n\n"), { fontSize = 15, whiteSpace = "normal", lineHeight = 1.6 })))
                    detail:Open()
                end, { height = 36, role = "secondary", width = "100%" })
            end
            cards[#cards + 1] = Visual.Card(children, { id = "achievement-" .. definition.id, gap = 8, padding = 12, borderColor = record and C.gold or C.rule })
        end
        if #cards == 0 then cards[1] = Visual.Text("这一页还没有收录。", { fontSize = 15, fontColor = C.secondary }) end
        body:AddChild(UI.ScrollView { id = "achievements-list", width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0, minHeight = 0,
            scrollX = false, children = { UI.Panel { width = "100%", gap = 9, children = cards } } })
        body:AddChild(UI.Row { width = "100%", gap = 8, alignItems = "center", children = {
            Visual.Button("上一页", function() page = page - 1; Render() end, { id = "achievements-previous", flex = 1, minWidth = 0, height = 40, disabled = page == 1, role = "secondary" }),
            Visual.Text(page .. " / " .. pages, { fontSize = 13, fontColor = C.secondary }),
            Visual.Button("下一页", function() page = page + 1; Render() end, { id = "achievements-next", flex = 1, minWidth = 0, height = 40, disabled = page == pages, role = "secondary" }),
        } })
    end
    Render()
    modal:AddContent(body)
    modal:Open()
end

return View
