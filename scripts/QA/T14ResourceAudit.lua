-- T14 资源审计入口；正式 main.lua 不引用。加载实际解析器返回的运行资源。
---@diagnostic disable: undefined-global
local UI = require "urhox-libs/UI"
local Art = require "Jiaye.Art"
local Audit = {}

local checked = {}
local missing = {}

local function Check(path, source, resourceType)
    assert(type(path) == "string" and path ~= "", source .. " 返回空资源路径。")
    table.insert(checked, { path = path, source = source, resourceType = resourceType or "Image" })
    local resource = cache:GetResource(resourceType or "Image", path)
    if not resource then table.insert(missing, { path = path, source = source }) end
end

local function Member(artId, age)
    return { id = artId .. ":audit", artId = artId, sex = artId:find("_m", 1, true) and "男" or "女", age = age, alive = true }
end

local portraitIds = { "portrait_m01", "portrait_m02", "portrait_f01", "portrait_f02" }
local stages = { { "infant", 2 }, { "child", 9 }, { "young", 20 }, { "adult", 35 }, { "elder", 65 } }
local eventTypes = {
    "medical_find", "notes_choice", "plan_work", "community_request", "school", "roof",
    "jade_search", "leader", "migration", "invite_branch", "legacy_pending",
}
local relicIds = { "book", "newbook", "ruler", "letter", "plan", "jade", "notes" }
local relicFormIds = {
    "genealogy.1", "genealogy.2", "genealogy.3", "ruler.1", "ruler.2", "ruler.3",
    "letter.1", "letter.2", "letter.3", "plan.1", "plan.2", "plan.3",
    "jade.1", "jade.2", "jade.3.heirloom", "jade.3.alliance", "notes.1", "notes.2",
    "notes.3.private", "notes.3.public",
}

local function AuditArtPaths()
    for _, portraitId in ipairs(portraitIds) do
        for _, stage in ipairs(stages) do
            local member = Member(portraitId, stage[2])
            local path = Art.Portrait(member)
            Check(path, "人物头像/" .. portraitId .. "/" .. stage[1])
            member.alive, member.ageAtDeath, member.age = false, member.age, 92
            assert(Art.Portrait(member) == path, "已故人物头像年龄改变。")
        end
    end

    for _, homeId in ipairs({ "rented", "simple", "courtyard", "estate" }) do
        for _, state in ipairs({ "normal", "damaged", "upgraded", "relocated" }) do
            Check(Art.House(homeId, state), "家宅/" .. homeId .. "/" .. state)
        end
    end

    for _, eventType in ipairs(eventTypes) do
        Check(Art.Event({ type = eventType }), "事件/" .. eventType)
    end
    Check(Art.Event({ type = "growth", jobId = "doctor" }), "事件/growth-doctor")
    Check(Art.Event({ type = "growth", jobId = "craft" }), "事件/growth-craft")
    Check(Art.Event({ type = "growth", jobId = "farm" }), "事件/growth-study")
    for _, relicId in ipairs(relicIds) do Check(Art.Relic(relicId), "信物/" .. relicId) end
    for _, relicId in ipairs(relicFormIds) do
        Check(Art.Relic(relicId), "信物/" .. relicId)
    end
end

local function AuditUiPaths()
    for _, role in ipairs({ "primary", "secondary", "danger" }) do
        for _, state in ipairs({ "default", "pressed", "selected", "disabled", "focus", "confirm", "busy" }) do
            Check(Art.Button(role, state), "按钮/" .. role .. "/" .. state)
        end
    end
    for _, name in ipairs({
        "family", "people", "estate", "relics", "history", "money", "grain", "land", "relationship", "lock", "unlock",
        "back", "forward", "random", "edit", "close", "check", "plus", "minus", "info", "warning", "year", "save",
        "search", "leader", "sick", "deceased", "house", "restore", "more", "loading",
    }) do
        for _, tone in ipairs({ "ink", "paper", "muted" }) do Check(Art.Icon(name, tone), "图标/" .. name .. "/" .. tone) end
    end
    for _, name in ipairs({ "mountains", "tree", "clouds", "seal_square", "seal_round", "paper_edge", "corner", "divider", "branch_line", "spouse_line", "bamboo", "portrait_backplate" }) do
        Check(Art.Decor(name), "装饰/" .. name)
    end
    for _, name in ipairs({ "paper_subtle_512", "paper_fiber_alpha_512", "paper_medium_512", "paper_aged_512" }) do
        Check(Art.Texture(name), "纹理/" .. name)
    end
    for _, name in ipairs({
        "landscape", "tableau", "startFamilyButton", "continueFamilyButton",
        "worldMountains", "worldCapital", "worldSilk", "worldSea",
    }) do
        Check(Art.Opening(name), "开局视觉/" .. name)
    end
end

local function AuditFonts()
    for _, path in ipairs({
        "Fonts/NotoSansSC-Regular.ttf", "Fonts/NotoSansSC-Bold.ttf",
        "Fonts/SourceHanSerifCN-Regular.otf", "Fonts/SourceHanSerifCN-SemiBold.otf",
    }) do
        Check(path, "字体/" .. path, "Font")
    end
end

local function Finish()
    assert(#missing == 0, "T14 发现资源路径缺失：" .. cjson.encode(missing))
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%", justifyContent = "center", alignItems = "center",
        children = { UI.Label { text = "T14 资源路径审计通过：" .. tostring(#checked) .. " 项", fontSize = 24 } },
    })
    print("T14_RESOURCE_AUDIT_PASS checked=" .. tostring(#checked) .. " missing=0")
    print("T14_RESOURCE_AUDIT_PLATFORM_WARNINGS uuid://-73mcwx1QB6NyLrwJxv8Kg uuid://u05oYbz5RtecsyHB9-bmKQ source=Maker固定预加载；工程源码与.meta无对应引用。")
end

function Audit.Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    AuditArtPaths()
    AuditUiPaths()
    AuditFonts()
    Finish()
end

function Audit.Stop()
    UI.Shutdown()
end

function Start() Audit.Start() end

function Stop() Audit.Stop() end

return Audit
