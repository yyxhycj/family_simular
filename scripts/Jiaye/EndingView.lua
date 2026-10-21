local UI = require "urhox-libs/UI"
local Skin = require "Jiaye.QianjiajiSkin"
local Visual = require "Jiaye.Visual"

local View = {}

function View.Build(app, evidenceText)
    local run = app.run
    local ending = assert(run.ending, "终章记录缺失。")
    local details = {}
    for _, item in ipairs(ending.evidence or {}) do
        details[#details + 1] = Skin.Text(evidenceText(run, item), {
            width = "100%", fontSize = 13, fontColor = Skin.Colors.muted, whiteSpace = "normal",
        })
    end
    local living = 0
    for _, member in ipairs(run.members) do if member.alive then living = living + 1 end end
    local function review()
        app.endingReviewedRunId = run.runId
        app.gameTab, app.historySection = "history", "annals"
        app:Render()
    end
    return UI.Panel {
        id = "ending-overlay", position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%", backgroundColor = {18, 38, 31, 220},
        pointerEvents = "auto", overflow = "hidden",
        children = {UI.SafeAreaView {width = "100%", height = "100%", edges = "all", children = {
            UI.Panel {width = "100%", flex = 1, minHeight = 0, backgroundColor = Skin.Colors.paper,
                children = {
                    Skin.Header {title = "家谱终章", subtitle = "这段家史，已收入旧卷", backText = "首页",
                        backId = "ending-home", onBack = function() app:ReturnToCover() end},
                    UI.ScrollView {id = "ending-scroll", flexGrow = 1, flexBasis = 0, minHeight = 0,
                        scrollX = false, showScrollbar = false, children = {
                            UI.Panel {width = "100%", maxWidth = 640, alignSelf = "center", padding = 24, gap = 20,
                                children = {
                                    Visual.Decor("seal_square", {width = 42, height = 42, alignSelf = "center"}),
                                    Skin.Text(ending.title, {id = "ending-title", width = "100%", fontSize = 36, textAlign = "center", whiteSpace = "normal"}),
                                    Skin.Text(tostring(ending.family) .. "氏 · 大晟历 " .. tostring(ending.year) .. " 年", {width = "100%", fontSize = 15, textAlign = "center", fontColor = Skin.Colors.muted}),
                                    Skin.Line(),
                                    Skin.Text(ending.summary, {width = "100%", fontSize = 19, whiteSpace = "normal", lineHeight = 1.7}),
                                    Skin.Text("历经 " .. tostring(ending.yearIndex) .. " 年 · " .. tostring(#run.members) .. " 位族人 · 在世 " .. living .. " 人", {width = "100%", fontSize = 14, whiteSpace = "normal"}),
                                    Skin.Text("落笔时家资 · 银 " .. run.money .. " 两 · 粮 " .. run.grain .. " 石 · 田 " .. run.land .. " 亩", {width = "100%", fontSize = 14, whiteSpace = "normal"}),
                                    UI.Panel {width = "100%", gap = 10, children = details},
                                }},
                        }},
                    UI.Panel {width = "100%", padding = 20, gap = 10, flexShrink = 0,
                        borderTopWidth = 1, borderTopColor = Skin.Colors.rule, children = {
                            Skin.Button("回顾家史", review, {id = "ending-review", width = "100%"}),
                            Skin.Button("新立家谱", function() app:PrepareNewRun() end, {id = "ending-new-family", width = "100%", role = "secondary"}),
                        }},
                }},
        }}},
    }
end

return View
