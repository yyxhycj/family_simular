-- 家业美术资源解析：身份资源与当前场景版本分开处理。
local Art = {}

local LEGACY_VERSION = "1.0.0"
local REVIEW_VERSION = "ink_v2_review"
local FORMAL_VERSION = "ink_v3_formal"
local LEGACY_ROOT = "Jiaye/V7/"
local REVIEW_ROOT = "Jiaye/InkV2/"
local FORMAL_ROOT = "image/"

local pools = {
    ["男"] = { "portrait_m01", "portrait_m02" },
    ["女"] = { "portrait_f01", "portrait_f02" },
}
local knownPortraits = {
    portrait_m01 = true, portrait_m02 = true, portrait_f01 = true, portrait_f02 = true,
}
local knownVersions = {
    [LEGACY_VERSION] = true,
    [REVIEW_VERSION] = true,
    [FORMAL_VERSION] = true,
}

local formalPortraits = {
    portrait_m01 = {
        infant = "portrait_m01_infant_formal_20260921084907.png",
        child = "portrait_m01_child_formal_20260921084907.png",
        young = "portrait_m01_young_formal_20260921084907.png",
        adult = "portrait_m01_formal_20260921084407.png",
        elder = "portrait_m01_elder_formal_20260921084907.png",
    },
    portrait_m02 = {
        infant = "portrait_m02_infant_formal_20260921084907.png",
        child = "portrait_m02_child_formal_20260921084907.png",
        young = "portrait_m02_young_formal_20260921084907.png",
        adult = "portrait_m02_formal_20260921084407.png",
        elder = "portrait_m02_elder_formal_20260921084907.png",
    },
    portrait_f01 = {
        infant = "portrait_f01_infant_formal_20260921084907.png",
        child = "portrait_f01_child_formal_20260921084907.png",
        young = "portrait_f01_young_formal_202609210851.png",
        adult = "portrait_f01_formal_20260921084407.png",
        elder = "portrait_f01_elder_formal_202609210852.png",
    },
    portrait_f02 = {
        infant = "portrait_f02_infant_formal_202609210854.png",
        child = "portrait_f02_child_formal_202609210856.png",
        young = "portrait_f02_young_formal_202609210858.png",
        adult = "portrait_f02_formal_20260921084407.png",
        elder = "portrait_f02_elder_formal_202609210859.png",
    },
}

local function requireKnown(value, message)
    if not value then error(message, 2) end
    return value
end

local function normalizeVersion(version)
    local resolved = version or LEGACY_VERSION
    requireKnown(knownVersions[resolved], "未知美术版本：" .. tostring(version))
    return resolved
end

local function hash(value)
    local result = 5381
    for index = 1, #value do result = (result * 33 + value:byte(index)) % 2147483647 end
    return result
end

function Art.NormalizeVersion(version)
    return normalizeVersion(version)
end

function Art.Assign(member, identity, artVersion)
    if type(member) ~= "table" or member.id == nil then error("成员编号无效，无法分配 artId。", 2) end
    local requestedVersion = normalizeVersion(artVersion)
    local assignedArtId = rawget(member, "artId")
    local assignedVersion = rawget(member, "artVersion")
    local fixedVersion = assignedVersion ~= nil and normalizeVersion(assignedVersion) or LEGACY_VERSION
    if assignedArtId ~= nil and assignedArtId ~= "" then
        requireKnown(knownPortraits[assignedArtId], "已有 artId 未登记，必须显式迁移：" .. tostring(assignedArtId))
        if assignedVersion ~= nil and artVersion ~= nil and fixedVersion ~= requestedVersion then
            error("成员 artVersion 已固定，不能覆盖：" .. tostring(assignedVersion), 2)
        end
        member.artVersion = fixedVersion
        return assignedArtId
    end
    if assignedVersion ~= nil and artVersion ~= nil and fixedVersion ~= requestedVersion then
        error("成员 artVersion 已固定，不能覆盖：" .. tostring(assignedVersion), 2)
    end

    local pool = pools[member.sex]
    requireKnown(pool, "当前性别没有对应头像池：" .. tostring(member.sex))
    local key = tostring(identity or "draft") .. ":" .. tostring(member.id)
    member.artId = pool[hash(key) % #pool + 1]
    member.artVersion = assignedVersion ~= nil and fixedVersion or requestedVersion
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
    if type(member) ~= "table" or not knownPortraits[member.artId] then error("未知人物 artId：" .. tostring(member and member.artId), 2) end
    requireKnown(size == "normal" or size == "detail", "未知头像尺寸：" .. tostring(size))
    requireKnown(visualStatus == nil or visualStatus == "sick" or visualStatus == "deceased" or visualStatus == "normal", "未知头像状态：" .. tostring(visualStatus))
    local age = member.alive == false and (member.ageAtDeath or member.age) or member.age
    if type(age) ~= "number" or age < 0 then error("人物年龄无效，无法选择头像：" .. tostring(member.id), 2) end
    local version = normalizeVersion(member.artVersion)
    local stage = member.artStageAtDeath or Art.Stage(age)
    local state = member.alive == false and "deceased" or (visualStatus == "sick" and "sick" or "normal")
    if version == FORMAL_VERSION and state == "normal" then
        local formalFile = formalPortraits[member.artId][stage]
        if formalFile then return FORMAL_ROOT .. formalFile end
    end
    if version == REVIEW_VERSION or version == FORMAL_VERSION then
        local base = REVIEW_ROOT .. "characters/" .. member.artId .. "/" .. stage
        if size == "detail" and state == "normal" then return base .. "_detail_768.png" end
        return base .. "_" .. state .. "_256.png"
    end
    local base = LEGACY_ROOT .. "characters/" .. member.artId .. "/" .. stage
    if size == "detail" then return base .. "_detail" .. (state == "normal" and "" or "_" .. state) .. ".png" end
    return base .. "_" .. state .. "_256.png"
end

function Art.SelectedOverlay() return LEGACY_ROOT .. "ui/portrait_selected.png" end
function Art.LeaderOverlay() return LEGACY_ROOT .. "ui/portrait_leader.png" end
function Art.FocusOverlay() return LEGACY_ROOT .. "ui/portrait_focus.png" end

function Art.Button(role, state)
    local roles = { primary = true, secondary = true, danger = true }
    local states = { default = true, pressed = true, selected = true, disabled = true, focus = true, confirm = true, busy = true }
    requireKnown(roles[role], "未知按钮角色：" .. tostring(role))
    requireKnown(states[state], "未知按钮状态：" .. tostring(state))
    return LEGACY_ROOT .. "ui/buttons/" .. role .. "_" .. state .. "@2x.png"
end

function Art.House(homeId, state, artVersion)
    local states = { normal = true, damaged = true, upgraded = true, relocated = true }
    requireKnown(states[state], "未知家宅状态：" .. tostring(state))
    requireKnown(homeId == "rented" or homeId == "simple" or homeId == "courtyard" or homeId == "estate", "未知家宅等级：" .. tostring(homeId))
    if normalizeVersion(artVersion) == REVIEW_VERSION or normalizeVersion(artVersion) == FORMAL_VERSION then
        return REVIEW_ROOT .. "houses/" .. homeId .. "_" .. state .. "_1200x560.png"
    end
    return LEGACY_ROOT .. "houses/" .. homeId .. "_" .. state .. ".png"
end

local eventMap = {
    medical_find = "medical", notes_choice = "medical", plan_work = "repair", community_request = "neighbors",
    school = "school", roof = "roof", jade_search = "jade", leader = "leadership", migration = "migration",
    invite_branch = "reunion", legacy_pending = "book",
}
local relicEventMap = { ruler = "ruler", book = "book", letter = "letter", plan = "repair", newbook = "reunion", jade = "jade", notes = "medical" }

local function eventArtId(event, relicId)
    if event.type == "relic_resolution" then return relicEventMap[relicId] end
    if event.type == "growth" then return event.jobId == "doctor" and "medical" or (event.jobId == "craft" and "repair" or "school") end
    return eventMap[event.type]
end

function Art.Event(event, relicId, artVersion)
    requireKnown(type(event) == "table", "事件对象无效，无法选择插画。")
    local version = normalizeVersion(artVersion)
    local artId = eventArtId(event, relicId)
    requireKnown(artId, "未知事件类型或信物事件映射：" .. tostring(event.type))
    if version == REVIEW_VERSION or version == FORMAL_VERSION then
        return REVIEW_ROOT .. "events/" .. artId .. "_1200x560.png"
    end
    return LEGACY_ROOT .. "events/" .. artId .. ".png"
end

local legacyRelicMap = {
    ruler = "ruler", book = "book", letter = "letter", plan = "plan", newbook = "newbook", jade = "jade", notes = "notes",
    ["genealogy.1"] = "book", ["genealogy.2"] = "newbook", ["genealogy.3"] = "newbook",
    ["ruler.1"] = "ruler", ["ruler.2"] = "ruler", ["ruler.3"] = "ruler",
    ["letter.1"] = "letter", ["letter.2"] = "letter", ["letter.3"] = "letter",
    ["plan.1"] = "plan", ["plan.2"] = "plan", ["plan.3"] = "plan",
    ["jade.1"] = "jade", ["jade.2"] = "jade", ["jade.3.heirloom"] = "jade", ["jade.3.alliance"] = "jade",
    ["notes.1"] = "notes", ["notes.2"] = "notes", ["notes.3.private"] = "notes", ["notes.3.public"] = "notes",
}
local reviewRelicMap = {
    ["genealogy.1"] = "genealogy_1", ["genealogy.2"] = "genealogy_2", ["genealogy.3"] = "genealogy_3",
    ["ruler.1"] = "ruler_1", ["ruler.2"] = "ruler_2", ["ruler.3"] = "ruler_3",
    ["letter.1"] = "letter_1", ["letter.2"] = "letter_2", ["letter.3"] = "letter_3",
    ["plan.1"] = "plan_1", ["plan.2"] = "plan_2", ["plan.3"] = "plan_3",
    ["jade.1"] = "jade_1", ["jade.2"] = "jade_2", ["jade.3.heirloom"] = "jade_3_heirloom", ["jade.3.alliance"] = "jade_3_alliance",
    ["notes.1"] = "notes_1", ["notes.2"] = "notes_2", ["notes.3.private"] = "notes_3_private", ["notes.3.public"] = "notes_3_public",
}
local reviewRelicAliases = {
    book = "genealogy.1", newbook = "genealogy.2", ruler = "ruler.1", letter = "letter.1", plan = "plan.1", jade = "jade.1", notes = "notes.1",
}

function Art.Relic(relicId, artVersion)
    requireKnown(relicId, "缺少信物 id")
    local version = normalizeVersion(artVersion)
    if version == REVIEW_VERSION or version == FORMAL_VERSION then
        local formId = reviewRelicAliases[relicId] or relicId
        local file = reviewRelicMap[formId]
        requireKnown(file, "未知信物形态：" .. tostring(relicId))
        return REVIEW_ROOT .. "relics/" .. file .. "_512.png"
    end
    local legacyId = legacyRelicMap[relicId]
    requireKnown(legacyId, "未知信物 id：" .. tostring(relicId))
    return LEGACY_ROOT .. "relics/" .. legacyId .. ".png"
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
    return LEGACY_ROOT .. "icons/" .. tostring(name) .. "_" .. tone .. "@2x.png"
end

function Art.Decor(name)
    local knownDecor = { mountains = true, tree = true, clouds = true, seal_square = true, seal_round = true, paper_edge = true, corner = true, divider = true, branch_line = true, spouse_line = true, bamboo = true, portrait_backplate = true }
    requireKnown(knownDecor[name], "未知装饰名称：" .. tostring(name))
    return LEGACY_ROOT .. "decor/" .. tostring(name) .. ".png"
end

function Art.Texture(name)
    local knownTextures = { paper_subtle_512 = true, paper_fiber_alpha_512 = true, paper_medium_512 = true, paper_aged_512 = true }
    requireKnown(knownTextures[name], "未知纸张纹理：" .. tostring(name))
    return LEGACY_ROOT .. "textures/" .. tostring(name) .. ".png"
end

function Art.Opening(name)
    local openingArt = {
        landscape = "Jiaye/Opening/01-水墨四境山河图.png",
        tableau = "Jiaye/Opening/02-水墨古风桌案与远眺人物素材集.png",
    }
    return requireKnown(openingArt[name], "未知开局视觉资源：" .. tostring(name))
end

function Art.Panel(state)
    local states = { default = true, selected = true, disabled = true, danger = true, confirmation = true }
    requireKnown(states[state], "未知面板状态：" .. tostring(state))
    return LEGACY_ROOT .. "ui/panels/" .. state .. "@2x.png"
end

return Art
