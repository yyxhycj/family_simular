local Data = require "Jiaye.Data"

local MarriageState = {}

MarriageState.Forms = {
    { id = "in", name = "迎入本家", detail = "配偶入户，共同承担本家生计，孩子归本家。" },
    { id = "out", name = "入居亲家", detail = "本人迁出，夫妻保留家谱记录，生计与孩子归亲家。" },
    { id = "dual", name = "两家往来", detail = "本人留家、配偶居外；成婚时约定孩子归属。" },
}
MarriageState.Weddings = {
    { id = "simple", name = "家常小礼", money = 4, grain = 1, gift = 0, reputation = 0 },
    { id = "regular", name = "乡里正礼", money = 10, grain = 3, gift = 2, reputation = 2 },
    { id = "grand", name = "广邀宾客", money = 24, grain = 6, gift = 6, reputation = 5 },
}
MarriageState.Projects = {
    tutor = { name = "塾师引读", fee = 6, work = 1, window = 6, job = "study", stat = "learn", gain = 1, charges = 3, detail = "付6两；实际读书每年学识+1，共3年。完成1年引读后，应试成功率加8个百分点，限1次，婚后6年内有效。" },
    official = { name = "任职引荐", fee = 4, work = 2, window = 6, job = "official", money = 4, reputation = 1, detail = "付4两；已有任职资格者实际任职2年，每年额外4两、声望1，婚后6年内完成。" },
    merchant = { name = "亲家商单", fee = 12, work = 1, window = 9, deadline = 2, job = "trade", reward = 20, cooldown = 3, limit = 3, detail = "投入12两，2年内实际行商1年收回20两，净得8两；每隔3年可接，9年内最多3单。未动用本金可退。" },
    doctor = { name = "医家授业", fee = 4, work = 2, window = 6, job = "medical", stat = "medicine", gain = 3, detail = "付4两；6年内实际学医2年，每年医术+3，受教人锁定。" },
    officer = { name = "军营护送", fee = 8, work = 1, window = 6, deadline = 2, job = "guard", statReq = "martial", min = 35, reward = 22, cooldown = 3, limit = 2, detail = "付8两行装费；18岁、武艺35、体魄50，2年内实际护卫1年得22两，净得14两；6年内最多2单、间隔3年。行装费不退。" },
    artisan = { name = "旧图改坊", fee = 20, work = 2, window = 1000, deadline = 4, job = "craft", statReq = "skill", min = 35, detail = "亲家交付唯一图纸；已有作坊、手艺35者投入20两，4年内实际制器2年。每年耗材10两，完工后作坊有人制器时年增4两；未用材料可退。" },
    clan = { name = "联谱访亲", fee = 10, work = 1, window = 6, job = "study", reputation = 6, detail = "付10两，6年内实际读书1年，声望+6，并获得2位成年对象的引见资格，有效3年。" },
}
MarriageState.Traits = {
    farming = { name = "耕读相济", detail = "同年有人耕作时，本代指定读书人实际读书可额外学识+1，共3年；传习需师长年长5岁、实际读书3年。" },
    diet = { name = "药膳家法", detail = "持有人照料家宅时，每年耗粮1石，最多2位休养者体魄+2；12岁、医术25并实际学医或持家2年可学会。" },
    thrift = { name = "持家有方", detail = "持有人实际照料家宅，全年生活开支减2两，最低为0；18岁、经营25并实际持家或行商2年可学会。" },
    trust = { name = "重诺家训", detail = "持有人亲自完成不同亲家事务，每项声望+2，最多3项；18岁，随师在不同年份完成2种事务可学会。" },
}

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

function MarriageState.Hash(value)
    local result = 17
    for index = 1, #value do result = (result * 131 + value:byte(index)) % 2147483647 end
    result = ((result ~ (result >> 16)) * 0x45d9f3b) & 0x7fffffff
    result = ((result ~ (result >> 16)) * 0x45d9f3b) & 0x7fffffff
    result = result ~ (result >> 16)
    return math.max(1, result)
end

local function Generator(seed)
    local state = seed
    return function(minimum, maximum)
        state = state * 48271 % 2147483647
        return minimum + state % (maximum - minimum + 1)
    end
end

local origins = {
    { name = "世代种田", job = "farm", stat = "learn" },
    { name = "沿街做工", job = "craft", stat = "skill" },
    { name = "随船经营", job = "trade", stat = "trade" },
    { name = "开馆教书", job = "teach", stat = "learn" },
    { name = "乡间行医", job = "doctor", stat = "medicine" },
    { name = "边地从军", job = "guard", stat = "martial" },
}
local changes = {
    { text = "收留了一位远行师傅", need = "study" },
    { text = "家中长辈渐老", need = "care" },
    { text = "新开一条商路", need = "trade" },
    { text = "连年支出耗去积蓄", need = "cash" },
    { text = "新置田业缺少人手", need = "labor" },
    { text = "想为下一代留住家业", need = "succession" },
    { text = "打算搬往新的地方", need = "move" },
}
local needNames = { study = "求学传艺", care = "照应长辈", trade = "寻找合伙", cash = "筹措现银", labor = "补足人手", succession = "承续家业", move = "迁居谋生" }
local wishes = { "想继续读书", "愿随伴侣远行", "希望留在故里", "想学一门手艺", "盼有独立生计" }
local surnames = { "顾", "沈", "周", "陆", "陶", "程", "许", "陈", "方", "苏", "孟", "叶" }
local roles = { "tutor", "official", "merchant", "doctor", "officer", "artisan", "clan" }
local roleNames = { tutor = "乡塾先生", official = "地方主簿", merchant = "商行东家", doctor = "医馆师傅", officer = "营中校尉", artisan = "作坊匠师", clan = "宗族族老" }
local aidKinds = { "grain", "skill", "money", "learn", "medicine", "martial" }
local traits = { "farming", "diet", "thrift", "trust" }

function MarriageState.GenerateHousehold(run)
    local world = run.marriage
    world.serial = world.serial + 1
    local id = "kin-" .. world.serial
    local random = Generator(MarriageState.Hash(tostring(world.seed) .. ":" .. id))
    local origin, change = origins[random(1, #origins)], changes[random(1, #changes)]
    local surname = surnames[random(1, #surnames)]
    local role = roles[random(1, #roles)]
    local wealth = random(1, 4)
    local assets = { money = random(12, 24) + wealth * 18, grain = random(12, 28), land = random(0, wealth), book = random(1, 3) == 1 }
    local age = random(42, 66)
    local household = {
        id = id, surname = surname, name = surname .. "家", placeId = Data.Places[random(1, #Data.Places)].id,
        createdYear = run.yearIndex, original = origin.name, history = origin.name .. "，后来" .. change.text .. "。", need = change.need,
        needText = needNames[change.need], wealth = wealth, assets = assets, claimed = {}, projects = {},
        patron = { name = surname .. (random(0, 1) == 0 and "叔衡" or "知秋"), role = role, title = roleNames[role], age = age, alive = true, retireAge = random(62, 70) },
        aidKind = aidKinds[random(1, #aidKinds)], traitId = random(1, 3) == 1 and traits[random(1, #traits)] or nil,
    }
    household.patron.active = age < household.patron.retireAge
    if role == "artisan" then household.blueprint = true end
    table.insert(world.households, household)
    for sibling = 1, 2 do
        local sex = random(0, 1) == 0 and "男" or "女"
        ---@type string[]
        local names = sex == "男" and Data.GivenNames.male or Data.GivenNames.female
        local stats = { learn = random(8, 30), skill = random(8, 30), medicine = random(8, 30), trade = random(8, 30), martial = random(8, 30) }
        local focus = ({ "learn", "skill", "medicine", "trade", "martial" })[random(1, 5)]
        stats[focus] = random(25, 65)
        local candidate = {
            id = id .. "-" .. sibling, householdId = id, name = surname .. names[random(1, #names)], sex = sex, age = random(18, 32),
            talent = random(1, 5), focus = focus, stats = stats, health = random(60, 90), wish = wishes[random(1, #wishes)],
            stay = random(1, 4) == 1, status = "available", createdYear = run.yearIndex,
        }
        local function Taken(name)
            for _, person in ipairs(run.members) do if person.name == name then return true end end
            for _, person in ipairs(world.candidates) do if person.name == name then return true end end
            return false
        end
        local first, second = 1, 1
        while Taken(candidate.name) do
            candidate.name = surname .. names[first] .. (second > 1 and names[second] or "")
            first = first + 1
            if first > #names then first = 1; second = second + 1 end
            assert(second <= #names, "议亲对象姓名已用尽。")
        end
        table.insert(world.candidates, candidate)
    end
    return household
end

function MarriageState.Ensure(run)
    for _, member in ipairs(run.members) do member.kinGeneration = member.kinGeneration or member.generation or 1 end
    if run.marriage ~= nil then return end
    for _, member in ipairs(run.members) do if member.spouseId then member.weddingRewardClaimed = true end end
    run.marriage = {
        version = 1, seed = MarriageState.Hash(tostring(run.openingSnapshot.rngSeed or run.rngState) .. ":marriage"), serial = 0,
        households = {}, candidates = {}, contracts = {}, projects = {}, traditions = {}, lessons = {}, objects = {}, stories = {}, introductions = {},
    }
    for _ = 1, 6 do MarriageState.GenerateHousehold(run) end
end

function MarriageState.Find(list, id)
    for _, item in ipairs(list or {}) do if item.id == id then return item end end
end

local function Count(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end

local function Stats(stats)
    if type(stats) ~= "table" then return false end
    for _, key in ipairs({ "learn", "skill", "medicine", "trade", "martial" }) do if not Count(stats[key]) or stats[key] > 100 then return false end end
    return true
end

function MarriageState.Validate(run, memberIds)
    local world = run.marriage
    if type(world) ~= "table" or world.version ~= 1 or not Count(world.seed) or world.seed < 1 or not Count(world.serial) then return false, "婚配世界版本或随机种子无效。" end
    for _, key in ipairs({ "households", "candidates", "contracts", "projects", "traditions", "lessons", "objects", "stories", "introductions" }) do
        if type(world[key]) ~= "table" then return false, "婚配记录缺少“" .. key .. "”。" end
    end
    local families, candidates, contracts = {}, {}, {}
    for _, household in ipairs(world.households) do
        if type(household) ~= "table" or type(household.id) ~= "string" or families[household.id] or not Data.Place(household.placeId) or not MarriageState.Projects[household.patron.role] then return false, "亲家身份或地点引用无效。" end
        families[household.id] = true
        for _, key in ipairs({ "money", "grain", "land" }) do
            local amount = household.assets[key]
            if type(amount) ~= "number" or amount < 0 or amount ~= math.floor(amount) then return false, "亲家家产账目无效。" end
        end
    end
    for _, candidate in ipairs(world.candidates) do
        if type(candidate.id) ~= "string" or not families[candidate.householdId] or candidates[candidate.id] or not Count(candidate.age) or candidate.age < 18 or not Data.Talents[candidate.talent]
            or not Data.FocusNames[candidate.focus] or not Stats(candidate.stats) or (candidate.sex ~= "男" and candidate.sex ~= "女")
            or not ({ available = true, married = true, departed = true })[candidate.status] then return false, "议亲对象记录无效。" end
        candidates[candidate.id] = true
    end
    for _, contract in ipairs(world.contracts) do
        if type(contract.id) ~= "string" or contracts[contract.id] or not memberIds[contract.memberId] or not memberIds[contract.spouseId] or not families[contract.householdId] or not candidates[contract.candidateId]
            or not MarriageState.Find(MarriageState.Forms, contract.form) or not MarriageState.Find(MarriageState.Weddings, contract.weddingId) or not Count(contract.year)
            or (contract.childHome ~= "home" and contract.childHome ~= "external") or type(contract.duties) ~= "table" or #contract.duties > 2 then return false, "婚约参与人或条款引用无效。" end
        contracts[contract.id] = true
        for _, duty in ipairs(contract.duties) do
            if duty.elderId and not memberIds[duty.elderId] then return false, "奉养长辈引用无效。" end
            if not ({ care = true, study = true, land = true })[duty.kind] or not Count(duty.progress) or not Count(duty.deadline)
                or (duty.targetId and not memberIds[duty.targetId]) or (duty.heirId and not memberIds[duty.heirId]) then return false, "婚后责任记录无效。" end
        end
        if contract.aid and (not memberIds[contract.aid.targetId] or not Count(contract.aid.remaining) or contract.aid.remaining > 3 or not Count(contract.aid.expires)) then return false, "亲家资助记录无效。" end
    end
    for _, project in ipairs(world.projects) do
        if not contracts[project.contractId] or not memberIds[project.actorId] or not MarriageState.Projects[project.kind] or not Count(project.progress)
            or not Count(project.started) or not Count(project.deadline) or not Count(project.unspent) then return false, "亲家事务引用无效。" end
    end
    for _, tradition in ipairs(world.traditions) do
        if not memberIds[tradition.holderId] or not MarriageState.Traits[tradition.kind] then return false, "家法传承引用无效。" end
    end
    for _, lesson in ipairs(world.lessons) do
        if not memberIds[lesson.mentorId] or not memberIds[lesson.studentId] or not MarriageState.Traits[lesson.kind] or not Count(lesson.progress) then return false, "传习关系引用无效。" end
    end
    for _, object in ipairs(world.objects) do
        if not memberIds[object.holderId] or not contracts[object.contractId] or (object.kind ~= "book" and object.kind ~= "blueprint")
            or (object.kind == "book" and (not Count(object.charges) or object.charges > 3)) then return false, "亲家物件记录无效。" end
    end
    for _, story in ipairs(world.stories) do if not contracts[story.contractId] then return false, "亲家往来婚约引用无效。" end end
    for _, token in ipairs(world.introductions) do if not Count(token.remaining) or token.remaining > 2 or not Count(token.expires) then return false, "引见名额记录无效。" end end
    for _, member in ipairs(run.members) do
        if member.residence ~= nil and member.residence ~= "home" and member.residence ~= "external" then return false, "族人居所记录无效。" end
        if member.marriageId and not contracts[member.marriageId] then return false, "族人婚约引用无效。" end
        if member.natalHouseholdId and not families[member.natalHouseholdId] then return false, "族人外家引用无效。" end
    end
    return true
end

MarriageState.Copy = Copy
return MarriageState
