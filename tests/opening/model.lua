local Opening = require "Jiaye.Opening"
local State = require "Jiaye.State"

local function same(left, right)
    return Opening.Equal(left, right)
end

local function signature(draft)
    local people = {}
    for _, member in ipairs(draft.members) do
        table.insert(people, table.concat({ member.name, member.age, member.sex, member.talent, member.experienceId, member.jobId }, ":"))
    end
    return table.concat({ draft.family, draft.periodId, draft.calendar, draft.originId, draft.placeId, draft.money, draft.grain, draft.land, table.concat(people, "/") }, "|")
end

local function onlyPageAndSeedChanged(before, after, page)
    local expected = State.Copy(before)
    for _, field in ipairs(Opening.Fields[page]) do expected[field] = State.Copy(after[field]) end
    expected.rngSeed = after.rngSeed
    return same(expected, after)
end

local function relations(member)
    return { id = member.id, age = member.age, sex = member.sex, parents = State.Copy(member.parents), spouseId = member.spouseId,
        talent = member.talent, focus = member.focus, experienceId = member.experienceId, trait = member.trait, jobId = member.jobId }
end

local function findLine(lines, label)
    for _, line in ipairs(lines) do if line.label == label then return line end end
end

return function()
    local profile = State.NewProfile()
    local results = {}

    do
        local unique, maxPopulation = {}, 0
        for seed = 1, 48 do
            local first = assert(Opening.Generate(profile, seed, "mortal"))
            local second = assert(Opening.Generate(profile, seed, "mortal"))
            assert(same(first, second), "相同种子必须生成同一草案")
            assert(#first.members >= 2 and #first.members <= 6, "人口必须在 2–6 人之间")
            maxPopulation = math.max(maxPopulation, #first.members)
            assert(#State.ValidateDraft(first, profile, false) == 0, "生成草案必须可直接开局")
            unique[signature(first)] = true
        end
        local sixPeople = assert(Opening.Generate(profile, 722, "mortal"))
        assert(#sixPeople.members == 6 and #State.ValidateDraft(sixPeople, profile, false) == 0, "六人上限家庭必须保持关系合法")
        maxPopulation = math.max(maxPopulation, #sixPeople.members)
        local count = 0; for _ in pairs(unique) do count = count + 1 end
        assert(count >= 12, "不同种子未产生足够的实质差异")
        assert(maxPopulation <= 6, "生成人口不得超过 6 人")
        table.insert(results, { id = "seeded_generation", samples = 48, distinct = count, maxPopulation = maxPopulation })
    end

    do
        local draft = assert(Opening.Generate(profile, 71, "mortal"))
        assert(State.ValidName("欧阳长名") and State.ValidName(string.rep("名", 20)) and not State.ValidName(string.rep("名", 21)), "复姓和 Unicode 长名必须按字符而非字节校验")
        local external
        for _, member in ipairs(draft.members) do if member.nameSource == "external" then external = member; break end end
        assert(external, "该固定夹具应包含外姓配偶")
        local custom = draft.members[1]
        custom.name, custom.nameSource, custom.givenName = "欧阳长名自定", "custom", nil
        external.givenName, external.name = "外", draft.family .. "外"
        local before = State.Copy(draft)
        local points = State.TotalPoints(draft)
        assert(Opening.RandomFamilyName(draft))
        assert(draft.rngSeed == before.rngSeed and State.TotalPoints(draft) == points, "姓名骰子不得推进整户随机或改变点数")
        assert(external.name == before.members[external.id].name and custom.name == "欧阳长名自定", "外姓和自定义姓名不得被猜姓")
        assert(Opening.Rename(draft, "司马"))
        assert(custom.name == "欧阳长名自定" and external.name == before.members[external.id].name)
        for _, member in ipairs(draft.members) do assert(same(relations(member), relations(before.members[member.id])), "改姓不得修改成员属性或关系") end
        for _, member in ipairs(draft.members) do
            if member.nameSource == "family" then assert(member.name == "司马" .. member.givenName) end
        end
        table.insert(results, { id = "name_isolation", family = draft.family, points = points })
    end

    do
        local draft = State.NewDraft()
        local original = State.Copy(draft)
        local invalid = State.Copy(draft.members[3]); invalid.age = 50
        assert(not Opening.EditMember(draft, invalid, draft.leaderId, profile), "非法亲缘年龄必须拒绝")
        assert(same(draft, original), "失败编辑不得改写原草案")
        invalid = State.Copy(draft.members[1]); invalid.jobId = "official"
        assert(not Opening.EditMember(draft, invalid, draft.leaderId, profile), "应试岗位不得作为开局安排")
        assert(same(draft, original))
        invalid = State.Copy(draft.members[1]); invalid.spouseId = invalid.id
        assert(not Opening.EditMember(draft, invalid, draft.leaderId, profile), "自婚配必须拒绝")
        assert(same(draft, original))
        local atLimit = State.Copy(draft); atLimit.money = 110
        local runAtLimit = State.NewRun(atLimit, profile)
        assert(State.TotalPoints(atLimit) == 100 and #State.ValidateDraft(atLimit, profile, false) == 0 and runAtLimit and runAtLimit.worldId == "mortal", "100 点凡世草案必须可开局并记录世界")
        local lines = State.PointLines(atLimit)
        assert(findLine(lines, "承平岁月").effect:find("工资倍率", 1, true) and findLine(lines, "林成 · 初始安排：手艺谋生") and findLine(lines, "林成 · 偏向：手艺"), "点数明细必须展示时期、安排和零点偏向的实际作用")
        local overLimit = State.Copy(atLimit); overLimit.money = 120
        local beforeOver = State.Copy(overLimit)
        assert(State.TotalPoints(overLimit) == 101 and #State.ValidateDraft(overLimit, profile, false) > 0 and not State.NewRun(overLimit, profile), "101 点草案必须拒绝")
        assert(same(overLimit, beforeOver), "被拒绝的超分草案不得被悄悄降级")
        local invalidWorld = State.Copy(atLimit); invalidWorld.worldId = "immortal"
        local beforeWorld = State.Copy(invalidWorld)
        assert(#State.ValidateDraft(invalidWorld, profile, false) > 0 and not State.NewRun(invalidWorld, profile), "非凡世草案必须拒绝开局")
        assert(same(invalidWorld, beforeWorld), "被拒绝的世界选择不得被改写")
        local beforePage = State.Copy(draft)
        local randomEstate = assert(Opening.RandomPage(draft, "estate", profile))
        assert(same(draft, beforePage) and onlyPageAndSeedChanged(beforePage, randomEstate, "estate"), "随机本页只能改本页字段和随机种子")
        local impossible = State.Copy(draft); impossible.money = 1010
        local beforeImpossible = State.Copy(impossible)
        assert(not Opening.RandomPage(impossible, "world", profile) and same(impossible, beforeImpossible), "随机无解必须完整保留原草案")
        local malformed = { members = { { name = false } }, money = false, grain = false, land = false, selectedRelicIds = false }
        assert(type(State.PointLines(malformed)) == "table", "非法草案的点数明细不能让界面崩溃")
        assert(#State.ValidateDraft(malformed, profile, false) > 0, "非法草案应返回问题而非抛出异常")
        table.insert(results, { id = "edit_validation", rejected = 3, pointLinesSafe = true, limits = "100/101", pageIsolation = true })
    end

    return results
end
