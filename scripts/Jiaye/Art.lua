-- V7 美术资源解析：只根据稳定身份和实际状态选择资源。
local Art = {}

local ROOT = "Jiaye/V7/"
local pools = {
    ["男"] = { "portrait_m01", "portrait_m02" },
    ["女"] = { "portrait_f01", "portrait_f02" },
}
local known = {
    portrait_m01 = true, portrait_m02 = true, portrait_f01 = true, portrait_f02 = true,
}

local function requireKnown(value, message)
    if not value then error(message, 2) end
    return value
end

local function hash(value)
    local result = 5381
    for index = 1, #value do result = (result * 33 + value:byte(index)) % 2147483647 end
    return result
end

function Art.Assign(member, identity)
    if type(member) ~= "table" or member.id == nil then error("成员编号无效，无法分配 artId。", 2) end
    local assignedArtId = rawget(member, "artId")
    if assignedArtId ~= nil and assignedArtId ~= "" then
        local knownArtId = rawget(known, assignedArtId)
        if knownArtId ~= true then error("已有 artId 未登记，必须显式迁移：" .. tostring(assignedArtId), 2) end
        return assignedArtId
    end
    local pool = pools[member.sex]
    requireKnown(pool, "当前性别没有对应头像池：" .. tostring(member.sex))
    local key = tostring(identity or "draft") .. ":" .. tostring(member.id)
    member.artId = pool[hash(key) % #pool + 1]
    member.artVersion = "1.0.0"
    return member.artId
end

function Art.Stage(age)
    if age < 5 then return "infant" end
    if age < 13 then return "child" end
    if age < 28 then return "young" end
    if age < 55 then return "adult" end
    return "elder"
end

function Art.Portrait(member, size, visualStatus)
    if type(member) ~= "table" or not known[member.artId] then error("未知人物 artId：" .. tostring(member and member.artId), 2) end
    requireKnown(size == "normal" or size == "detail", "未知头像尺寸：" .. tostring(size))
    requireKnown(visualStatus == nil or visualStatus == "sick" or visualStatus == "deceased" or visualStatus == "normal", "未知头像状态：" .. tostring(visualStatus))
    local age = member.alive == false and (member.ageAtDeath or member.age) or member.age
    if type(age) ~= "number" or age < 0 then error("人物年龄无效，无法选择头像：" .. tostring(member.id), 2) end
    local stage = member.artStageAtDeath or Art.Stage(age)
    local state = member.alive == false and "deceased" or (visualStatus == "sick" and "sick" or "normal")
    local base = ROOT .. "characters/" .. member.artId .. "/" .. stage
    if size == "detail" then return base .. "_detail" .. (state == "normal" and "" or "_" .. state) .. ".png" end
    return base .. "_" .. state .. "_256.png"
end

function Art.SelectedOverlay() return ROOT .. "ui/portrait_selected.png" end
function Art.LeaderOverlay() return ROOT .. "ui/portrait_leader.png" end
function Art.FocusOverlay() return ROOT .. "ui/portrait_focus.png" end

function Art.Button(role, state)
    local roles = { primary = true, secondary = true, danger = true }
    local states = { default = true, pressed = true, selected = true, disabled = true, focus = true, confirm = true, busy = true }
    requireKnown(roles[role], "未知按钮角色：" .. tostring(role))
    requireKnown(states[state], "未知按钮状态：" .. tostring(state))
    return ROOT .. "ui/buttons/" .. role .. "_" .. state .. "@2x.png"
end

function Art.House(homeId, state)
    local states = { normal = true, damaged = true, upgraded = true, relocated = true }
    requireKnown(states[state], "未知家宅状态：" .. tostring(state))
    requireKnown(homeId == "rented" or homeId == "simple" or homeId == "courtyard" or homeId == "estate", "未知家宅等级：" .. tostring(homeId))
    return ROOT .. "houses/" .. homeId .. "_" .. state .. ".png"
end

local eventMap = {
    medical_find = "medical", notes_choice = "medical", plan_work = "repair", community_request = "neighbors",
    school = "school", roof = "roof", jade_search = "jade", leader = "leadership", migration = "migration",
    invite_branch = "reunion", legacy_pending = "book",
}
local relicMap = { ruler = "ruler", book = "book", letter = "letter", plan = "repair", newbook = "reunion", jade = "jade", notes = "medical" }

function Art.Event(event, relicId)
    requireKnown(type(event) == "table", "事件对象无效，无法选择插画。")
    local artId = eventMap[event.type]
    if event.type == "relic_resolution" then artId = relicMap[relicId] end
    if event.type == "growth" then artId = event.jobId == "doctor" and "medical" or (event.jobId == "craft" and "repair" or "school") end
    requireKnown(artId, "未知事件类型：" .. tostring(event.type))
    return ROOT .. "events/" .. artId .. ".png"
end

function Art.Relic(relicId)
    requireKnown(relicId, "缺少信物 id")
    local knownRelics = { ruler = true, book = true, letter = true, plan = true, newbook = true, jade = true, notes = true }
    requireKnown(knownRelics[relicId], "未知信物 id：" .. tostring(relicId))
    return ROOT .. "relics/" .. tostring(relicId) .. ".png"
end

function Art.Icon(name, tone)
    tone = tone or "ink"
    local tones = { ink = true, paper = true, muted = true }
    requireKnown(tones[tone], "未知图标色调：" .. tostring(tone))
    local knownIcons = {
        family = true, people = true, estate = true, relics = true, history = true, money = true, grain = true, land = true,
        relationship = true, lock = true, unlock = true, back = true, forward = true, random = true, edit = true, close = true,
        check = true, plus = true, minus = true, info = true, warning = true, year = true, save = true, search = true,
        leader = true, sick = true, deceased = true, house = true, restore = true, more = true, loading = true,
    }
    requireKnown(knownIcons[name], "未知图标：" .. tostring(name))
    return ROOT .. "icons/" .. tostring(name) .. "_" .. tone .. "@2x.png"
end

function Art.Decor(name)
    local knownDecor = { mountains = true, tree = true, clouds = true, seal_square = true, seal_round = true, paper_edge = true, corner = true, divider = true, branch_line = true, spouse_line = true, bamboo = true, portrait_backplate = true }
    requireKnown(knownDecor[name], "未知装饰：" .. tostring(name))
    return ROOT .. "decor/" .. tostring(name) .. ".png"
end

function Art.Texture(name)
    local knownTextures = { paper_subtle_512 = true, paper_fiber_alpha_512 = true, paper_medium_512 = true, paper_aged_512 = true }
    requireKnown(knownTextures[name], "未知纸张纹理：" .. tostring(name))
    return ROOT .. "textures/" .. tostring(name) .. ".png"
end

function Art.Panel(state)
    local states = { default = true, selected = true, disabled = true, danger = true, confirmation = true }
    requireKnown(states[state], "未知面板状态：" .. tostring(state))
    return ROOT .. "ui/panels/" .. state .. "@2x.png"
end

return Art
