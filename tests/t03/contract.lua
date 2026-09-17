-- T03 只验证生成式整户草案与三种随机命令；不把摘要布局或完整编辑器计作本步证据。
local App = require "Jiaye.App"
local Opening = require "Jiaye.Opening"
local State = require "Jiaye.State"

local function Same(left, right)
    return Opening.Equal(left, right)
end

local function Signature(draft)
    local members = {}
    for _, member in ipairs(draft.members) do
        table.insert(members, table.concat({ member.id, member.name, member.age, member.sex, member.talent,
            member.focus, member.experienceId, member.jobId, table.concat(member.parents, ","), member.spouseId or 0 }, ":"))
    end
    return table.concat({ draft.family, draft.periodId, draft.calendar, draft.originId, draft.placeId,
        draft.money, draft.grain, draft.land, draft.homeId, tostring(draft.workshop), tostring(draft.shop),
        table.concat(draft.selectedRelicIds, ","), table.concat(members, "/") }, "|")
end

local function AssertFamily(draft, profile)
    assert(draft.worldId == "mortal" and draft.generatorVersion == 1, "生成草案必须标明凡世与生成版本")
    assert(#draft.members >= 2 and #draft.members <= 6, "生成家庭人口必须在 2–6 人")
    assert(#State.ValidateDraft(draft, profile, false) == 0, "生成草案必须可直接开局")
    local leader = State.FindMember(draft.members, draft.leaderId)
    assert(leader and leader.age >= 18, "每户必须有成年首任族长")
    for _, relicId in ipairs(draft.selectedRelicIds) do
        assert(profile.unlockedRelicIds[relicId], "生成器不得把未解锁或图中示例物件塞入开局池")
    end
end

local function Run()
    local profile = State.NewProfile()
    local profileBefore = State.Copy(profile)
    local signatures, families, populations, maxPopulation, minPopulation = {}, {}, {}, 0, 99

    for seed = 1, 128 do
        local first = assert(Opening.Generate(profile, seed, "mortal"))
        local second = assert(Opening.Generate(profile, seed, "mortal"))
        assert(Same(first, second), "同输入、同版本、同种子必须复现相同家庭")
        AssertFamily(first, profile)
        signatures[Signature(first)] = true
        families[first.family] = true
        populations[#first.members] = true
        maxPopulation = math.max(maxPopulation, #first.members)
        minPopulation = math.min(minPopulation, #first.members)
    end
    assert(Same(profile, profileBefore), "整户生成只能读取收藏池，不能修改局外收藏")
    local distinct, familyCount, populationKinds = 0, 0, 0
    for _ in pairs(signatures) do distinct = distinct + 1 end
    for _ in pairs(families) do familyCount = familyCount + 1 end
    for _ in pairs(populations) do populationKinds = populationKinds + 1 end
    assert(distinct >= 64 and familyCount >= 4 and populationKinds >= 3 and minPopulation == 2 and maxPopulation == 5,
        "不同种子必须产生实质差异，且覆盖可生成的人口与姓氏范围："
        .. tostring(distinct) .. "/" .. tostring(familyCount) .. "/" .. tostring(populationKinds) .. "/" .. tostring(minPopulation) .. "-" .. tostring(maxPopulation))
    local sixMemberFixture = assert(Opening.Generate(profile, 722, "mortal"))
    AssertFamily(sixMemberFixture, profile)
    assert(sixMemberFixture.family == "顾" and sixMemberFixture.periodId == "unrest"
        and sixMemberFixture.calendar == 132 and sixMemberFixture.rngSeed == 1416712955
        and sixMemberFixture.leaderId == 1 and #sixMemberFixture.members == 6,
        "固定 seed 722 必须保留可复核的六人合法家庭夹具")

    local replayFixture = assert(Opening.Generate(profile, 71, "mortal"))
    local replayRun = assert(State.NewRun(replayFixture, profile))
    assert(replayRun.rngState == replayFixture.rngSeed, "开始时必须把草案随机源写入运行状态")
    local savedOk, saveMessage = State.Save(profile, replayFixture, replayRun)
    assert(savedOk, "生成草案的运行状态无法保存：" .. tostring(saveMessage))
    local saved = assert(State.Load())
    assert(saved.run.rngState == replayFixture.rngSeed and Same(saved.run.openingSnapshot, replayFixture),
        "重启回读必须保留草案快照与随机源")

    do
        local app = App.New()
        app.profile = profile
        app.draft = assert(Opening.Generate(profile, 71, "mortal"))
        local currentRun = assert(State.NewRun(State.NewDraft(), profile))
        app.run = currentRun
        local beforeDraft, beforeRun = State.Copy(app.draft), State.Copy(currentRun)
        app:ChangeHouse()
        assert(app.houseUndo and not Same(app.draft, beforeDraft), "换一家必须生成新整户并保留上一家")
        assert(Same(app.run, beforeRun), "换一家不得污染正在运行的家族")
        app:UndoHouse()
        assert(Same(app.draft, beforeDraft) and Same(app.run, beforeRun), "恢复上一家必须完整恢复原草案")

        local source = Opening.Generate
        Opening.Generate = function() return nil, "注入无可用组合" end
        app:ChangeHouse()
        assert(Same(app.draft, beforeDraft) and Same(app.run, beforeRun)
            and app.openingFeedback == "注入无可用组合", "无可用组合必须保留草案与正在运行的家族")
        Opening.Generate = source
    end

    do
        local draft = assert(Opening.Generate(profile, 71, "mortal"))
        local beforeName = State.Copy(draft)
        local external = nil
        for _, member in ipairs(draft.members) do
            if member.nameSource == "external" then external = member; break end
        end
        assert(external, "固定 seed 71 必须包含外姓成员夹具")
        local custom = draft.members[1]
        custom.name, custom.nameSource, custom.givenName = "欧阳长名自定", "custom", nil
        local pointsBeforeName = State.TotalPoints(draft)
        assert(Opening.RandomFamilyName(draft))
        assert(draft.rngSeed == beforeName.rngSeed and draft.nameSeed ~= beforeName.nameSeed,
            "家族姓名骰子只能推进命名种子")
        assert(external.name == beforeName.members[external.id].name and custom.name == "欧阳长名自定"
            and State.TotalPoints(draft) == pointsBeforeName,
            "姓名骰子不得改外姓、自定义姓名或开局点数")
        assert(Opening.Rename(draft, "司马"), "复姓必须作为完整家族称谓保存")
        assert(external.name == beforeName.members[external.id].name and custom.name == "欧阳长名自定", "复姓不得猜改外姓或自定义全名")
        for _, member in ipairs(draft.members) do
            if member.nameSource == "family" then assert(member.name == "司马" .. member.givenName, "本姓关联成员必须随完整复姓更新") end
        end

        local beforePage = State.Copy(draft)
        local page = assert(Opening.RandomPage(draft, "estate", profile))
        assert(Same(draft, beforePage), "本页随机只能产生候选，不能直接改展示草案")
        for key, value in pairs(page) do
            if key ~= "rngSeed" then
                local onPage = false
                for _, field in ipairs(Opening.Fields.estate) do if key == field then onPage = true end end
                assert(onPage or Same(value, beforePage[key]), "本页随机不得变成整户随机")
            end
        end
    end

    return {
        { id = "seeded_households", samples = 128, distinct = distinct, families = familyCount, populationKinds = populationKinds, minPopulation = minPopulation, maxPopulation = maxPopulation, sixMemberSeed = 722 },
        { id = "seed_persistence", seed = 71, family = replayFixture.family, calendar = replayFixture.calendar, rngState = replayRun.rngState, memberCount = #replayFixture.members },
        { id = "change_house", runUntouched = true, undoRestored = true, failurePreserved = true },
        { id = "command_scope", separateNameSeed = true, externalAndCustomProtected = true, compoundFamilyName = true, pageCandidatePure = true },
    }
end

local function Restart()
    local saved = assert(State.Load())
    assert(saved.run.rngState == saved.draft.rngSeed and Same(saved.run.openingSnapshot, saved.draft),
        "新 Lua 进程回读后必须保留草案快照与随机源")
    return {
        id = "restart_seed_persistence", family = saved.draft.family, calendar = saved.draft.calendar,
        rngState = saved.run.rngState, memberCount = #saved.draft.members,
    }
end

return { run = Run, restart = Restart }
