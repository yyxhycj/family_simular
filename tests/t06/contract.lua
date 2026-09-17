-- T06 验证年度事实、人物经历、代际、任期和保管权同源；不替代引擎绘制或真机输入。
local UI = require "urhox-libs/UI"
local App = require "Jiaye.App"
local Economy = require "Jiaye.Economy"
local Simulation = require "Jiaye.Simulation"
local State = require "Jiaye.State"

local function same(left, right) return cjson.encode(left) == cjson.encode(right) end

local function find(root, value)
    if root.text == value then return root end
    for _, child in ipairs(root.children or {}) do
        local result = find(child, value)
        if result then return result end
    end
end

local function contains(root, value)
    if type(root.text) == "string" and root.text:find(value, 1, true) then return root end
    for _, child in ipairs(root.children or {}) do
        local result = contains(child, value)
        if result then return result end
    end
end

local function fresh()
    local profile, draft = State.NewProfile(), State.NewDraft()
    return assert(State.NewRun(draft, profile)), profile, draft
end

local function factFor(run, memberId, kind)
    for _, fact in ipairs(run.facts or {}) do
        if fact.kind == kind then
            for _, id in ipairs(fact.memberIds or {}) do if id == memberId then return fact end end
        end
    end
end

local function run()
    local run, profile, draft = fresh()
    local preview = Economy.Preview(State.Copy(run))
    local frozenStart = { money = run.money, grain = run.grain, land = run.land }
    assert(Simulation.AdvanceYear(run, profile), "正常年度未能推进")
    local ledger = assert(run.annualLedgers[1], "年度结算没有留下账本")
    assert(ledger.yearStart.money == frozenStart.money and ledger.yearStart.grain == frozenStart.grain and ledger.yearStart.land == frozenStart.land
        and ledger.netMoney == preview.netMoney and ledger.netGrain == preview.netGrain and ledger.factId, "年初快照或账本分项没有与正式结算同源")
    local frozenLedger = State.Copy(ledger)
    assert(Simulation.AdvanceYear(run, profile), "第二年未能推进")
    assert(same(run.annualLedgers[2], frozenLedger), "旧年度账本在后续结算中被改写")

    local hungry, hungryProfile, hungryDraft = fresh()
    hungry.members = { hungry.members[1] }
    local survivor = hungry.members[1]
    survivor.age, survivor.health, survivor.jobId, survivor.spouseId, survivor.birthPlan = 30, 60, "play", nil, false
    hungry.money, hungry.grain, hungry.land, hungry.metrics.stable, hungry.metrics.foodYears = 0, 0, 0, 4, 7
    assert(Simulation.AdvanceYear(hungry, hungryProfile))
    assert(hungry.metrics.stable == 0 and hungry.metrics.foodYears == 0 and hungry.lastLedger.foodSatisfied == false and survivor.health == 48
        and hungry.lastLedger.resourcesExhausted and hungry.ending and hungry.ending.id == "collapse" and hungry.ending.automatic
        and hungry.ending.evidence[1].current == 0 and hungry.ending.evidence[2].current == 0 and #hungryProfile.endingRecords == 1 and survivor.alive,
        "钱粮同时耗尽后没有写入可回看的家道终局")
    local closedHungry = State.Copy(hungry)
    assert(not Simulation.SetJob(hungry, survivor.id, "farm") and same(hungry, closedHungry), "家道终局后仍可改写运行家谱")
    local collapseApp = App.New(); collapseApp.profile, collapseApp.draft, collapseApp.run, collapseApp.screen, collapseApp.gameTab = hungryProfile, hungryDraft, hungry, "game", "family"
    collapseApp:Render()
    assert(contains(UI.root, "本局已落笔 · 家道散尽") and contains(UI.root, "年度结算后公库与存粮同时归零时自动写入"), "家道终局没有在家族页显示准确状态")
    collapseApp.gameTab, collapseApp.historySection = "history", "annals"; collapseApp:Render()
    assert(contains(UI.root, "年末：公库与存粮同时归零。"), "家道终局没有在年鉴显示钱粮归零")

    local lineage, lineageProfile = fresh()
    lineage.money = 200
    lineage.members[1].sex, lineage.members[1].age = "女", 30
    lineage.members[2].sex, lineage.members[2].age = "女", 30
    lineage.rngState = 1
    assert(Simulation.AdvanceYear(lineage, lineageProfile))
    local born = lineage.members[#lineage.members]
    assert(born.age == 0 and born.generation == math.max(lineage.members[1].generation, lineage.members[2].generation) + 1 and factFor(lineage, born.id, "birth"),
        "同性爱侣添丁没有按亲长最大代际入谱或未写入事实")
    local guardian = lineage.members[1]
    assert(Simulation.Adopt(lineage, guardian.id))
    local adopted = lineage.members[#lineage.members]
    assert(adopted.generation == guardian.generation + 1 and factFor(lineage, adopted.id, "adoption"), "收养代际或经历事实不一致")
    local sibling = lineage.members[3]
    sibling.age, sibling.sex, sibling.spouseId, lineage.rngState = 24, "女", nil, 1
    assert(Simulation.Marry(lineage, sibling.id))
    local spouse = lineage.members[#lineage.members]
    sibling.jobYears.teach, spouse.jobYears.teach = 2, 2
    assert(spouse.sex == sibling.sex and spouse.generation == sibling.generation and Simulation.EndingProgress(lineage, "scholar")[1][2] == 1, "同性爱侣婚入或代际记录错误")

    local handover, handoverProfile, handoverDraft = fresh()
    handover.members = { handover.members[1], handover.members[2] }
    handover.members[1].age, handover.members[2].age = 89, 30
    for _, member in ipairs(handover.members) do member.spouseId, member.birthPlan = nil, false end
    handover.rngState = 1
    assert(Simulation.AdvanceYear(handover, handoverProfile))
    assert(not handover.members[1].alive and handover.relicInstances[1].custodianId == nil, "族长离世后物件仍指向已故保管人")
    local leaderEvent = assert(Simulation.PendingEvents(handover)[1])
    assert(leaderEvent.type == "leader" and Simulation.ResolveLeaderEvent(handover, leaderEvent.instanceId, handover.members[2].id))
    assert(handover.leaderId == handover.members[2].id and handover.relicInstances[1].custodianId == nil
        and factFor(handover, handover.members[1].id, "death") and factFor(handover, handover.members[2].id, "leadership"),
        "继任、离世和保管权没有写入同一份可回看事实")
    local dead = handover.members[1]
    local deadApp = App.New(); deadApp.profile, deadApp.draft, deadApp.run, deadApp.screen = handoverProfile, handoverDraft, handover, "game"
    deadApp:OpenRunMember(dead.id)
    assert(find(UI.modal, "生活与经历") and contains(UI.modal, "已故 · 生平可读") and contains(UI.modal, "离世，生平被保留在家谱中"), "已故成员不能在人物页回看离世事实")
    deadApp:Render()
    assert(find(UI.root, "家谱") and find(UI.root, "⌂\n家族") and find(UI.root, "人\n族人"), "家族主页没有渲染家谱入口与五项底部导航")
    deadApp:ConfirmEventChoice({ instanceId = "visual-only", type = "growth", title = "人生节点", memberId = dead.id }, "暂缓", "结果：当前仅确认事件界面层级。", "defer")
    assert(find(UI.modal, "人生节点") and find(UI.modal, "你准备这样决定") and find(UI.modal, "确认这个决定"), "事件确认没有渲染来源、决定和确认层级")

    local career, careerProfile, careerDraft = fresh()
    local worker = career.members[1]
    worker.age, worker.stats.learn, worker.jobId = 30, 100, "craft"
    local beforeCancel = State.Copy(career)
    local app = App.New(); app.profile, app.draft, app.run, app.screen = careerProfile, careerDraft, career, "game"
    app:Render(); app:ConfirmRunJob(worker.id, "farm")
    local cancel = assert(find(UI.modal, "取消")); cancel.onClick(cancel)
    assert(same(career, beforeCancel), "岗位确认取消仍修改了运行态")
    app:ConfirmRunJob(worker.id, "farm")
    local confirm = assert(find(UI.modal, "确认安排")); confirm.onClick(confirm)
    assert(worker.jobId == "farm" and factFor(career, worker.id, "job"), "岗位确认没有写入人物事实")
    worker.jobId = "study"; worker.stats.learn = 100
    assert(Simulation.AdvanceYear(career, careerProfile))
    local growth = nil
    for _, event in ipairs(Simulation.PendingEvents(career)) do if event.type == "growth" and event.memberId == worker.id then growth = event end end
    assert(growth and Simulation.ResolveEvent(career, growth.instanceId, "acknowledge", careerProfile) and factFor(career, worker.id, "growth"),
        "真实成长节点没有生成通知/决定或没有写入经历")
    local staleGrowth = { instanceId = "growth-missing-member", type = "growth", status = "pending", memberId = "missing-member", growthId = "adult" }
    career.events[#career.events + 1] = staleGrowth
    assert(not Simulation.ResolveEvent(career, staleGrowth.instanceId, "acknowledge", careerProfile) and staleGrowth.status == "cancelled",
        "找不到族人的成长提醒没有安全作废")
    worker.stats.learn = 100
    assert(Simulation.TakeExam(career, worker.id) and factFor(career, worker.id, "exam"), "应试结果没有写入人物事实")

    local ages, agesProfile, agesDraft = fresh()
    local toddler = ages.members[4]
    toddler.age, toddler.jobId = 2, "play"
    ages.money = 100
    assert(not State.CanUseJob(toddler, "study") and State.CanUseJob(toddler, "play") and State.CanUseJob(toddler, "rest"), "幼年岗位没有按年龄收紧")
    assert(not Simulation.TakeExam(ages, toddler.id) and not Simulation.Marry(ages, toddler.id)
        and not Simulation.Adopt(ages, toddler.id) and not Simulation.AppointLeader(ages, toddler.id)
        and not Simulation.TransferRelic(ages, ages.relicInstances[1].instanceId, toddler.id), "幼年成员仍能执行成年家事")
    toddler.age = 5
    assert(State.CanUseJob(toddler, "study"), "读书没有在 5 岁开放")
    toddler.age = 12
    assert(State.CanUseJob(toddler, "apprentice") and State.CanUseJob(toddler, "medical") and State.CanUseJob(toddler, "train"), "少年培养安排没有在 12 岁开放")
    toddler.age = 18
    assert(State.CanUseJob(toddler, "farm") and State.IsAdult(toddler), "成年安排没有在 18 岁开放")
    local parentA, parentB = ages.members[2], ages.members[1]
    parentA.sex, parentB.sex, parentA.age, parentB.age = "女", "女", 20, 20
    assert(not State.CanPlanBirth(parentA) and not State.CanPlanBirth(parentB) and not Simulation.SetBirthPlan(ages, parentA.id, true), "添丁计划在年龄前可写入")
    parentA.age, parentB.age = 21, 21
    assert(State.CanPlanBirth(parentA) and State.CanPlanBirth(parentB) and Simulation.SetBirthPlan(ages, parentA.id, true), "添丁计划没有在窗口起点开放")
    parentA.age, parentB.age = 61, 61
    assert(not State.CanPlanBirth(parentA) and not State.CanPlanBirth(parentB), "添丁计划超过年龄窗口仍可写入")
    toddler.age = 2
    local ageApp = App.New(); ageApp.profile, ageApp.draft, ageApp.run, ageApp.screen = agesProfile, agesDraft, ages, "game"
    ageApp:OpenRunMember(toddler.id)
    local arrangementTab = assert(find(UI.modal, "安排"), "人物页缺少安排入口")
    arrangementTab.onClick(arrangementTab)
    assert(find(UI.modal, "幼年 · 2 岁") and find(UI.modal, "随家人生活") and find(UI.modal, "休养")
        and not find(UI.modal, "应试（10 两）") and not find(UI.modal, "安排婚配（12 两）")
        and not find(UI.modal, "收养孩子（8 两）") and not find(UI.modal, "任命为族长"), "幼年人物页仍展示成年行动")

    assert(State.Save(careerProfile, careerDraft, career))
    local loaded = assert(State.Load())
    assert(#loaded.run.annualLedgers >= 1 and #loaded.run.facts >= 1, "年度账本或人物事实没有被保存")
    local resumed = App.New(); resumed:Load(); resumed.gameTab = "history"; resumed.historySection = "annals"; resumed:Render()
    assert(find(UI.root, "年度账本"), "家史缺少年度账本入口")
    resumed.historySection = "terms"; resumed:Render()
    assert(find(UI.root, "历任族长") and find(UI.root, "查看此人生平"), "家史缺少历任族长入口")
    assert(dead and not dead.alive and factFor(handover, dead.id, "death"), "已故成员不可回看其离世事实")
    return {
        annualLedgerFrozen = true, hungerResets = true, collapseReadOnly = true, collapseUI = true, lineage = { born = born.generation, adopted = adopted.generation, spouse = spouse.generation },
        custodyRecovered = true, factsPersisted = true, historyEntrances = true, ageRules = true,
    }
end

local function restart()
    local app = App.New(); app:Load()
    assert(app.run and #app.run.annualLedgers >= 1 and #app.run.facts >= 1, "重启后年度账本或人物事实丢失")
    return { year = app.run.yearIndex, ledgers = #app.run.annualLedgers, facts = #app.run.facts }
end

return { run = run, restart = restart }
