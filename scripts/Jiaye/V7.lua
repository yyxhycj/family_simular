local V7 = {}

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
}

V7.Images = {
    courtyard = "Jiaye/V7/courtyard.webp",
    manor = "Jiaye/V7/manor.webp",
    rural = "Jiaye/V7/rural.webp",
    street = "Jiaye/V7/street.webp",
    ruler = "Jiaye/V7/ruler.webp",
    adultMan = "Jiaye/V7/adult-man.webp",
    adultWoman = "Jiaye/V7/adult-woman.webp",
    youngWoman = "Jiaye/V7/young-woman.webp",
    elderMan = "Jiaye/V7/elder-man.webp",
    boy = "Jiaye/V7/boy.webp",
    girl = "Jiaye/V7/girl.webp",
}

function V7.HomeImage(homeId)
    if homeId == "estate" then return V7.Images.manor end
    if homeId == "courtyard" or homeId == "simple" then return V7.Images.courtyard end
    return V7.Images.rural
end

function V7.AvatarId(member)
    if type(member) ~= "table" then return V7.Images.adultMan end
    if type(member.avatarId) == "string" and member.avatarId ~= "" then return member.avatarId end
    if (member.age or 0) >= 60 then return V7.Images.elderMan end
    if (member.age or 0) < 18 then return member.sex == "女" and V7.Images.girl or V7.Images.boy end
    if member.sex == "女" then
        return (member.id or 0) % 2 == 0 and V7.Images.adultWoman or V7.Images.youngWoman
    end
    return V7.Images.adultMan
end

function V7.EventImage(eventType)
    if eventType == "relic_resolution" or eventType == "plan_work" or eventType == "roof" then return V7.Images.ruler end
    if eventType == "community_request" or eventType == "medical_find" then return V7.Images.rural end
    return V7.Images.street
end

return V7
