-- 开局命令只修改草案；渲染、预估、创建均不调用生成器。
local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local Opening = {}
Opening.Fields = {
    world = { "worldId", "periodId", "calendar", "originId", "placeId" },
    people = { "members", "leaderId", "nextId" },
    estate = { "money", "grain", "land", "homeId", "workshop", "shop", "habitId", "tieId" },
    relics = { "selectedRelicIds" },
}

function Opening.Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Opening.Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function Opening.Snapshot(draft, page)
    local snapshot = {}
    for _, key in ipairs(Opening.Fields[page] or {}) do snapshot[key] = State.Copy(draft[key]) end
    return snapshot
end

function Opening.Restore(draft, page, snapshot)
    for _, key in ipairs(Opening.Fields[page] or {}) do draft[key] = State.Copy(snapshot[key]) end
end

local sequence = 0
function Opening.FreshSeed()
    sequence = sequence + 1
    return (os.time() + math.floor(os.clock() * 1000000) + sequence * 104729) % 2147483646 + 1
end

local function randomSource(seed)
    local source = { rngState = math.floor(seed) % 2147483646 + 1 }
    local function roll(a, b) return State.Random(source, a, b) end
    local function pick(list) return list[roll(1, #list)] end
    return source, roll, pick
end

function Opening.Rename(draft, family)
    if not State.ValidName(family) then return false, "请输入 1–20 字的家族称谓，不含换行。" end
    for _, member in ipairs(draft.members) do
        if member.nameSource == "family" and (not State.ValidName(member.givenName) or not State.ValidName(family .. member.givenName)) then
            return false, "关联成员的名字无效或超过 20 字，请先修正名字。"
        end
    end
    draft.family = family
    for _, member in ipairs(draft.members) do
        if member.nameSource == "family" then member.name = family .. member.givenName end
    end
    return true, "名字已保存，点数和家底不变。"
end

function Opening.RandomFamilyName(draft)
    local source, _, pick = randomSource(draft.nameSeed or draft.rngSeed)
    local ok, message = Opening.Rename(draft, pick(Data.Surnames))
    -- 姓名骰子只推进自己的命名种子，不能影响整户/分页随机。
    if ok then draft.nameSeed = source.rngState end
    return ok, message
end

local function giveName(member, family, pick)
    member.givenName = pick(Data.GivenNames[member.sex == "男" and "male" or "female"])
        .. (pick({ true, false }) and pick(Data.GivenNames[member.sex == "男" and "male" or "female"]) or "")
    member.nameSource = member.nameSource or "external"
    local surname = member.nameSource == "family" and family or pick(Data.Surnames)
    member.name = surname .. member.givenName
end

local function configureMember(member, pick, roll)
    member.avatarId = member.avatarId or ((member.age or 0) < 18 and (member.sex == "女" and "Jiaye/V7/girl.webp" or "Jiaye/V7/boy.webp") or (member.sex == "女" and "Jiaye/V7/young-woman.webp" or "Jiaye/V7/adult-man.webp"))
    member.talent = roll(1, #Data.Talents)
    member.focus = pick({ "general", "learn", "skill", "medicine", "trade", "martial" })
    local experiences = {}
    for _, experience in ipairs(Data.Experiences) do
        if State.IsAdult(member) or experience.id == "none" or (member.age >= Data.AgeRules.basicExperience and experience.id == "basic") then
            table.insert(experiences, experience)
        end
    end
    local experience = pick(experiences)
    member.experienceId = experience.id
    local jobs = {}
    for _, id in ipairs(Data.JobOrder) do
        local job = Data.Jobs[id]
        if not job.exam and member.age >= job.min and (not job.req or experience.values[job.req[1]] >= job.req[2]) then
            table.insert(jobs, id)
        end
    end
    member.jobId = pick(jobs)
    member.trait = pick({ "踏实", "好奇", "细致", "仁厚", "沉静", "爽朗" })
end

local function randomPage(candidate, page, profile, roll, pick)
    if page == "world" then
        local period = pick(Data.Periods)
        candidate.periodId = period.id; candidate.calendar = pick(period.years)
        candidate.originId = pick(Data.Origins).id; candidate.placeId = pick(Data.Places).id
    elseif page == "people" then
        for _, member in ipairs(candidate.members) do
            configureMember(member, pick, roll)
            -- 明确自定义/旧档未声明归属的姓名不被本页随机覆盖。
            if member.nameSource == "family" or member.nameSource == "external" then giveName(member, candidate.family, pick) end
        end
    elseif page == "estate" then
        candidate.money = roll(0, 12) * Data.OpeningCosts.moneyUnit
        candidate.grain = roll(0, 10) * Data.OpeningCosts.grainUnit; candidate.land = roll(0, 3)
        candidate.homeId = pick(Data.Homes).id
        candidate.workshop = roll(1, 4) == 1; candidate.shop = roll(1, 4) == 1
        candidate.habitId = pick(Data.Habits).id; candidate.tieId = pick(Data.Ties).id
    elseif page == "relics" then
        candidate.selectedRelicIds = {}
        for _, relic in ipairs(Data.Relics) do
            if profile.unlockedRelicIds[relic.id] and roll(1, 2) == 1 then table.insert(candidate.selectedRelicIds, relic.id) end
        end
    end
end

function Opening.RandomPage(draft, page, profile)
    if not Opening.Fields[page] then return nil, "此页没有随机配置。" end
    local source, roll, pick = randomSource(draft.rngSeed)
    for _ = 1, 256 do
        local candidate = State.Copy(draft)
        randomPage(candidate, page, profile, roll, pick)
        if #State.ValidateDraft(candidate, profile, false) == 0 then
            candidate.rngSeed = source.rngState
            return candidate
        end
    end
    return nil, "暂未找到合法组合，已保留原草案；可以先调整其他页。"
end

function Opening.Generate(profile, seed, worldId)
    if worldId and worldId ~= "mortal" then return nil, "当前仅支持凡世，草案未改变。" end
    local source, roll, pick = randomSource(seed)
    for _ = 1, 512 do
        local draft = State.NewDraft()
        draft.generatorVersion = 2; draft.family = pick(Data.Surnames); draft.members = {}
        local function add(age, sourceName, parents)
            local member = { id = #draft.members + 1, age = age, sex = pick({ "男", "女" }),
                parents = parents or {}, nameSource = sourceName }
            giveName(member, draft.family, pick); configureMember(member, pick, roll)
            table.insert(draft.members, member)
            return member
        end
        local leader = add(roll(22, 58), "family")
        local adult = add(roll(math.max(18, leader.age - 8), math.min(66, leader.age + 8)), roll(1, 3) == 1 and "family" or "external")
        local couple = adult.nameSource == "external"
        if couple then
            giveName(adult, draft.family, pick)
            leader.spouseId = adult.id; adult.spouseId = leader.id
        end
        if roll(1, 3) == 1 then
            local elder = add(roll(leader.age + 18, math.min(90, leader.age + 35)), "family")
            leader.parents = { elder.id }
            if not couple then adult.parents = {} end
        end
        for _ = 1, roll(0, 3) do
            local parents = couple and { leader.id, adult.id } or { leader.id }
            add(roll(0, math.min(24, leader.age - 18, couple and adult.age - 18 or 24)), "family", parents)
        end
        draft.nextId = #draft.members + 1; draft.leaderId = leader.id
        for _, page in ipairs({ "world", "estate", "relics" }) do randomPage(draft, page, profile, roll, pick) end
        draft.habitId = "none"
        draft.tieId = "none"
        if #State.ValidateDraft(draft, profile, false) == 0 then
            draft.rngSeed = source.rngState
            draft.nameSeed = draft.rngSeed
            return draft
        end
    end
    return nil, "暂未生成合法家庭，原草案与家谱仍保留，请再试一次。"
end

function Opening.EditMember(draft, editing, leaderId, profile)
    if type(draft) ~= "table" or type(editing) ~= "table" then return nil, "成员编辑数据无效，原草案未改变。" end
    local candidate = State.Copy(draft)
    local found = false
    for _, member in ipairs(candidate.members) do
        if member.id == editing.id then
            found = true
            for key in pairs(member) do member[key] = nil end
            for key, value in pairs(editing) do member[key] = State.Copy(value) end
        elseif member.spouseId == editing.id then member.spouseId = nil end
    end
    if not found then return nil, "找不到要编辑的成员，原草案未改变。" end
    if editing.spouseId then
        local spouse = State.FindMember(candidate.members, editing.spouseId)
        if spouse then
            if spouse.spouseId then
                local former = State.FindMember(candidate.members, spouse.spouseId)
                if former then former.spouseId = nil end
            end
            spouse.spouseId = editing.id
        end
    end
    candidate.leaderId = leaderId
    local issues = State.ValidateDraft(candidate, profile, true)
    if #issues > 0 then return nil, table.concat(issues, "\n") end
    return candidate
end

return Opening
