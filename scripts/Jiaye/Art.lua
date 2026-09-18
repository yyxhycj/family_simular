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

local function hash(value)
    local result = 5381
    for index = 1, #value do result = (result * 33 + value:byte(index)) % 2147483647 end
    return result
end

function Art.Assign(member, identity)
    if type(member) ~= "table" or member.id == nil then return nil, "成员编号无效，无法分配 artId。" end
    if member.artId then
        if known[member.artId] then return member.artId end
        return nil, "已有 artId 未登记，保留原值并等待显式迁移。"
    end
    local pool = pools[member.sex]
    if not pool then return nil, "当前性别没有对应头像池。" end
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
    if type(member) ~= "table" or not known[member.artId] then return nil end
    local age = member.alive == false and (member.ageAtDeath or member.age) or member.age
    if type(age) ~= "number" or age < 0 then return nil end
    local stage = member.artStageAtDeath or Art.Stage(age)
    local state = member.alive == false and "deceased" or (visualStatus == "sick" and "sick" or "normal")
    local base = ROOT .. "characters/" .. member.artId .. "/" .. stage
    if size == "detail" then return base .. "_detail" .. (state == "normal" and "" or "_" .. state) .. ".png" end
    return base .. "_" .. state .. "_256.png"
end

function Art.SelectedOverlay() return ROOT .. "ui/portrait_selected.png" end
function Art.LeaderOverlay() return ROOT .. "ui/portrait_leader.png" end

function Art.Button(role, state)
    local roles = { primary = true, secondary = true, danger = true }
    local states = { default = true, pressed = true, selected = true, disabled = true, focus = true, confirm = true, busy = true }
    if not roles[role] or not states[state] then return nil end
    return ROOT .. "ui/buttons/" .. role .. "_" .. state .. "@2x.png"
end

function Art.House(homeId, state)
    local states = { normal = true, damaged = true, upgraded = true, relocated = true }
    if not states[state] then state = "normal" end
    if homeId ~= "rented" and homeId ~= "simple" and homeId ~= "courtyard" and homeId ~= "estate" then return nil end
    return ROOT .. "houses/" .. homeId .. "_" .. state .. ".png"
end

local eventMap = {
    medical_find = "medical", notes_choice = "medical", plan_work = "repair", community_request = "neighbors",
    school = "school", roof = "roof", jade_search = "jade", leader = "leadership", migration = "migration",
    invite_branch = "reunion",
}
local relicMap = { ruler = "ruler", book = "book", letter = "letter", plan = "repair", newbook = "reunion", jade = "jade", notes = "medical" }

function Art.Event(event, relicId)
    if type(event) ~= "table" then return nil end
    local artId = eventMap[event.type]
    if event.type == "relic_resolution" then artId = relicMap[relicId] end
    if event.type == "growth" then artId = event.jobId == "doctor" and "medical" or (event.jobId == "craft" and "repair" or "school") end
    if not artId then return nil end
    return ROOT .. "events/" .. artId .. ".png"
end

function Art.Relic(relicId)
    if not relicId then return nil end
    return ROOT .. "relics/" .. tostring(relicId) .. ".png"
end

function Art.Icon(name, tone)
    tone = tone or "ink"
    return ROOT .. "icons/" .. tostring(name) .. "_" .. tone .. "@2x.png"
end

function Art.Decor(name)
    return ROOT .. "decor/" .. tostring(name) .. ".png"
end

function Art.Texture(name)
    return ROOT .. "textures/" .. tostring(name) .. ".png"
end

return Art
