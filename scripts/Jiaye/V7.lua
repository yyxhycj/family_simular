local Art = require "Jiaye.Art"
local V7 = { Art = Art }

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
    seal = "Jiaye/V7/decor/seal_square.png",
}

function V7.HomeImage(homeId, state)
    return Art.House(homeId, state or "normal")
end

function V7.HouseState(run)
    if type(run) ~= "table" then return "normal" end
    if run.homeState == "damaged" or run.homeState == "upgraded" or run.homeState == "relocated" then return run.homeState end
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

return V7
