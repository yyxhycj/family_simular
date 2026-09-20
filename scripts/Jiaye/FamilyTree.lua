local UI = require "urhox-libs/UI"
local State = require "Jiaye.State"
local Data = require "Jiaye.Data"
local V7 = require "Jiaye.V7"
local Visual = require "Jiaye.Visual"

local Tree = UI.Panel:Extend("JiayeFamilyTree")

function Tree:Init(props)
    UI.Panel.Init(self, props)
    self.nodesById = {}
    self.members = props.members
end

local function line(nvg, points)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, points[1][1], points[1][2])
    for index = 2, #points do nvgLineTo(nvg, points[index][1], points[index][2]) end
    nvgStroke(nvg)
end

function Tree:Render(nvg)
    self:RenderFullBackground(nvg)
    local color = V7.Colors.gold
    nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], 180))
    nvgStrokeWidth(nvg, 1)
    local points = {}
    for id, node in pairs(self.nodesById) do
        local portrait, tile = node.portrait:GetAbsoluteLayout(), node.tile:GetAbsoluteLayout()
        points[id] = { x = portrait.x + portrait.w / 2, y = portrait.y + portrait.h / 2,
            top = portrait.y, bottom = tile.y + tile.h, radius = portrait.w / 2 }
    end
    local married = {}
    for _, member in ipairs(self.members) do
        local child = points[member.id]
        if child then
            local spouse = member.spouseId and points[member.spouseId]
            if spouse and not married[member.id] and not married[member.spouseId] then
                married[member.id], married[member.spouseId] = true, true
                local left, right = child.x < spouse.x and child or spouse, child.x < spouse.x and spouse or child
                line(nvg, { { left.x + left.radius, left.y }, { right.x - right.radius, right.y } })
            end
            local parents = {}
            for _, parentId in ipairs(member.parents or {}) do
                if points[parentId] then table.insert(parents, points[parentId]) end
            end
            if #parents > 0 then
                local x, bottom = 0, 0
                for _, parent in ipairs(parents) do x = x + parent.x; bottom = math.max(bottom, parent.bottom) end
                x = x / #parents
                local startY = #parents > 1 and parents[1].y or bottom
                local bridgeY = child.top - 16
                line(nvg, { { x, startY }, { x, bridgeY }, { child.x, bridgeY }, { child.x, child.top } })
            end
        end
    end
end

local FamilyTree = {}

function FamilyTree.Build(app)
    local generations, order = {}, {}
    for _, member in ipairs(app.run.members) do
        local generation = State.Generation(app.run.members, member.id)
        if not generations[generation] then generations[generation] = {}; table.insert(order, generation) end
        table.insert(generations[generation], member)
    end
    table.sort(order)
    local rows, widest, shown = {}, 1, {}
    for _, generation in ipairs(order) do
        if not app.familyGeneration or app.familyGeneration == 0 or app.familyGeneration == generation then
            local arranged, seen = {}, {}
            for _, member in ipairs(generations[generation]) do
                if not seen[member.id] then
                    table.insert(arranged, member); seen[member.id] = true
                    for _, spouse in ipairs(generations[generation]) do
                        if spouse.id == member.spouseId and not seen[spouse.id] then
                            table.insert(arranged, spouse); seen[spouse.id] = true
                        end
                    end
                end
            end
            widest = math.max(widest, #arranged)
            table.insert(rows, { generation = generation, members = arranged })
            for _, member in ipairs(arranged) do table.insert(shown, member) end
        end
    end
    local width = math.max(math.min(UI.GetWidth(), 480) - 32, widest * 84 + 28)
    local tree = Tree { width = width, height = math.max(140, #rows * 148), gap = 22, paddingVertical = 8, members = shown }
    for rowIndex, row in ipairs(rows) do
        local nodes = {}
        for _, member in ipairs(row.members) do
            local leader = member.id == app.run.leaderId
            local portrait = Visual.Portrait(member, { size = 52, leader = leader })
            local tile = UI.Button { text = "", width = 72, height = 126, padding = 0, gap = 2,
                backgroundColor = {0,0,0,0}, hoverBackgroundColor = {0,0,0,0}, pressedBackgroundColor = {0,0,0,0},
                borderWidth = 0, borderRadius = 0, alignItems = "center", justifyContent = "flex-start",
                onClick = function() app:OpenRunMember(member.id) end,
                children = {
                    portrait,
                    Visual.Text(member.name, { fontSize = 15, textAlign = "center", maxLines = 2, width = "100%" }),
                    Visual.Text(tostring(member.age) .. "岁 · " .. tostring(member.talent) .. "/5", { fontSize = 12, textAlign = "center" }),
                    Visual.Text(member.alive and Data.Jobs[member.jobId].name or "已故", { fontSize = 12, textAlign = "center", fontColor = V7.Colors.secondary }),
                } }
            tree.nodesById[member.id] = { portrait = portrait, tile = tile }
            table.insert(nodes, tile)
        end
        tree:AddChild(UI.Panel { height = 126, flexDirection = "row", justifyContent = "center", alignItems = "flex-start", gap = 12,
            paddingLeft = 20, children = nodes })
        tree:AddChild(Visual.Text("第" .. tostring(row.generation) .. "代", { position = "absolute", left = 0,
            top = (rowIndex - 1) * 148 + 30, width = 20, fontSize = 11, fontColor = V7.Colors.secondary }))
    end
    local filters = { Visual.Button("全代", function() app.familyGeneration = 0; app:Render() end, { role = "secondary", selected = (app.familyGeneration or 0) == 0 }) }
    for _, generation in ipairs(order) do
        table.insert(filters, Visual.Button("第" .. generation .. "代", function() app.familyGeneration = generation; app:Render() end,
            { role = "secondary", selected = app.familyGeneration == generation }))
    end
    local children = {
        UI.Row { justifyContent = "space-between", alignItems = "center", children = {
            Visual.Text((app.run.openingSnapshot.family or "") .. "氏家谱", { fontSize = 20, flex = 1, whiteSpace = "normal" }),
            Visual.Button(tostring(#app.run.members) .. " 人  ›", function() app.gameTab = "people"; app:Render() end, { role = "secondary", fontSize = 14, width = 74 }),
        } },
    }
    if #order > 3 then table.insert(children, UI.Panel { flexDirection = "row", flexWrap = "wrap", gap = 6, children = filters }) end
    table.insert(children, UI.ScrollView { height = math.max(140, #rows * 148), scrollX = true, scrollY = false, showScrollbar = widest > 4, children = { tree } })
    return UI.Panel { gap = 8, children = children }
end

return FamilyTree
