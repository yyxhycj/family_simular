local Art = require "Jiaye.Art"
local V7 = { Art = Art }

V7.Tokens = {
    caption = 12, body = 16, control = 15, secondary = 13,
    label = 16, title = 29, panelTitle = 23, buttonText = 15,
    bodyLineHeight = 1.75, lineHeight = 1.75,
    icon = 24, iconStrokeAt24 = 1.65, portrait = 64, relic = 56,
    border = 1, doubleFrameGap = 3, buttonRadius = 3, cardRadius = 10,
    panelRadius = 10, paperRadius = 10, sheetTopRadius = 12,
    primaryHeight = 48, buttonHeight = 48, touchMin = 44,
    pageInset = 17, sectionGap = 14, cardPadding = 12, paperPadding = 16,
    buttonSlice = { 36, 36, 36, 36 }, panelSlice = { 20, 20, 20, 20 },
    eventImage = 132, houseImage = 118,
}

V7.Colors = {
    paper = {247, 240, 223, 255},
    paperLight = {255, 249, 235, 255},
    ink = {41, 63, 55, 255},
    secondary = {115, 116, 102, 255},
    primary = {53, 92, 73, 255},
    selected = {226, 232, 216, 255},
    gold = {164, 139, 88, 255},
    rule = {213, 199, 167, 255},
    danger = {162, 83, 59, 255},
    pressed = {38, 71, 56, 255},
    disabledSurface = {223, 221, 207, 255},
    disabledInk = {119, 121, 109, 255},
}

V7.Images = {
    paperTexture = Art.Texture("paper_subtle_512"),
    paperFiber = Art.Texture("paper_fiber_alpha_512"),
    seal = Art.Decor("seal_square"),
}

function V7.HomeImage(homeId, state)
    return Art.House(homeId, state or "normal")
end

function V7.HouseState(run)
    if type(run) ~= "table" then return "normal" end
    if run.homeState == "normal" or run.homeState == "damaged" or run.homeState == "upgraded" or run.homeState == "relocated" then return run.homeState end
    if run.flags and run.flags.houseDamaged then return "damaged" end
    if run.metrics and (run.metrics.migrations or 0) > 0 then return "relocated" end
    return "normal"
end

function V7.AvatarId(member)
    return Art.Portrait(member, "normal")
end

function V7.EventImage(event, relicId)
    return Art.Event(event, relicId)
end

function V7.ButtonImage(role, state)
    return Art.Button(role, state)
end

function V7.ButtonTextColor(role, state)
    if state == "disabled" then return V7.Colors.disabledInk end
    if role == "secondary" then return V7.Colors.ink end
    return V7.Colors.paperLight
end

return V7
