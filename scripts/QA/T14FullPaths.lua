local State = require "Jiaye.State"
local Simulation = require "Jiaye.Simulation"
local Economy = require "Jiaye.Economy"
local OriginState = require "Jiaye.OriginState"
local Origin = require "Jiaye.OriginSystem"
local RelicDefinitions = require "Jiaye.RelicDefinitions"
local RelicState = require "Jiaye.RelicState"
local Relics = require "Jiaye.RelicSystem"

local T14 = {}
local PREFIX = "[T14FullPaths]"
local FILE_PATH = ".tmp/jiaye_t14_full_paths.export.json"
local defects = {}

local function fail(caseId, path, condition, reproduce)
    error(PREFIX .. " FAIL case=" .. caseId .. " path=" .. path .. " condition=" .. condition .. " reproduce=" .. reproduce, 2)
end

local function check(caseId, path, condition, reproduce)
    if not condition then fail(caseId, path, "false", reproduce) end
end

local function pass(caseId, detail)
    print(PREFIX .. " PASS " .. caseId .. " | " .. detail)
end

local function recordDefect(caseId, path, condition, reproduce)
    table.insert(defects, { caseId = caseId, path = path, condition = condition, reproduce = reproduce })
    print(PREFIX .. " FAIL case=" .. caseId .. " path=" .. path .. " condition=" .. condition .. " reproduce=" .. reproduce)
end

local function memberSpec(id, name, age, experienceId, jobId, focus)
    return { id = id, name = name, age = age, experienceId = experienceId, jobId = jobId, focus = focus or "general" }
end

local function makeDraft(options)
    options = options or {}
    local base = State.NewDraft()
    local specs = options.members or {
        memberSpec(1, "验收甲", 42, "craft", "craft", "skill"),
        memberSpec(2, "验收乙", 40, "basic", "farm", "general"),
    }
    base.family = "T14验收"
    base.originId = options.originId or "artisan"
    base.artVersion = "ink_v2_review"
    base.rulesVersion = 2
    base.relicRulesVersion = RelicDefinitions.VERSION
    base.originRulesVersion = options.withOrigin and OriginState.VERSION or nil
    base.money = options.money or 80
    base.grain = options.grain or 24
    base.land = options.land or 1
    base.rngSeed = options.rngSeed or 72831
    base.members = {}
    for _, spec in ipairs(specs) do
        table.insert(base.members, {
            id = spec.id, name = spec.name, sex = spec.sex or (spec.id % 2 == 1 and "男" or "女"),
            age = spec.age, parents = spec.parents or {}, spouseId = spec.spouseId,
            talent = spec.talent or 2, focus = spec.focus, experienceId = spec.experienceId,
            trait = spec.trait or "T14验收用真实开局", jobId = spec.jobId,
        })
    end
    base.selectedRelicIds = nil
    base.selectedRelicFormIds = options.forms or { "ruler.1" }
    base.relicUsers = options.relicUsers or {}
    base.relicCustodians = options.relicCustodians or {}
    for _, formId in ipairs(base.selectedRelicFormIds) do
        if base.relicUsers[formId] == nil then base.relicUsers[formId] = 1 end
    end
    return base
end

local function newRun(options)
    local profile = State.NewProfile()
    local draft = makeDraft(options)
    for _, formId in ipairs(draft.selectedRelicFormIds or {}) do profile.unlockedRelicForms[formId] = true end
    local run, issues = State.NewRun(draft, profile)
    check(options.caseId, "State.NewRun", run ~= nil, issues and table.concat(issues, "；") or "开局返回空运行家谱")
    for _, member in ipairs(run.members) do
        local canPlan = State.CanPlanBirth(member)
        if canPlan then
            local ok, message = Simulation.SetBirthPlan(run, member.id, false)
            check(options.caseId, "Simulation.SetBirthPlan(" .. tostring(member.id) .. ")", ok, message or "暂缓添丁失败")
        end
    end
    return run, profile, draft
end

local function validate(caseId, run, profile, draft)
    local ok, message = State.ValidateSavePayload({ saveSchemaVersion = 2, profile = profile, draft = draft, run = run })
    check(caseId, "State.ValidateSavePayload", ok, message or "存档结构校验失败")
end

local function setJob(caseId, run, memberId, jobId)
    local member = State.FindMember(run.members, memberId)
    check(caseId, "State.FindMember(" .. tostring(memberId) .. ")", member ~= nil, "成员不存在")
    if member.jobId == jobId then return end
    local ok, message = Simulation.SetJob(run, memberId, jobId)
    check(caseId, "Simulation.SetJob(" .. tostring(memberId) .. "," .. jobId .. ")", ok, message or "岗位安排失败")
end

local function resolvePending(caseId, run, profile)
    for _, event in ipairs(Simulation.PendingEvents(run)) do
        local ok, message = Simulation.ResolveEvent(run, event.instanceId, "defer", profile)
        check(caseId, "Simulation.ResolveEvent(" .. tostring(event.instanceId) .. ",defer)", ok, message or "待决事件无法处理")
    end
end

local function advance(caseId, run, profile, years, beforeYear)
    years = years or 1
    for _ = 1, years do
        if beforeYear then beforeYear(run, run.yearIndex + 1) end
        resolvePending(caseId, run, profile)
        local ok, message = Simulation.AdvanceYear(run, profile)
        check(caseId, "Simulation.AdvanceYear(" .. tostring(run.yearIndex + 1) .. ")", ok, message or "实际年度结算失败")
    end
end

local function primary(caseId, run, familyId)
    local instance = RelicState.Primary(run, familyId)
    check(caseId, "RelicState.Primary(" .. familyId .. ")", instance ~= nil, "开局未形成对应信物实例")
    return instance
end

local function factByKind(run, kind)
    for _, fact in ipairs(run.facts or {}) do
        if fact.kind == kind then return fact end
    end
    return nil
end

local function transactionSum(run, actionId)
    local total = 0
    for _, entry in ipairs(run.relicTransactions or {}) do
        if entry.actionId == actionId and (entry.money or 0) > 0 then total = total + entry.money end
    end
    return total
end

local function transactionGrainSum(run, actionId)
    local total = 0
    for _, entry in ipairs(run.relicTransactions or {}) do
        if entry.actionId == actionId and (entry.grain or 0) > 0 then total = total + entry.grain end
    end
    return total
end

local function startRelic(caseId, run, profile, actionId, input)
    local ok, message = Relics.Start(run, profile, actionId, input or {})
    check(caseId, "RelicSystem.Start(" .. actionId .. ")", ok, message or "正式信物行动拒绝执行")
end

local function quoteRelic(caseId, run, actionId, input)
    local quote = Relics.Quote(run, actionId, input or {})
    check(caseId, "RelicSystem.Quote(" .. actionId .. ")", quote.allowed, table.concat(quote.reasons or {}, "；"))
    return quote
end

local function originRun(caseId, originId, members, extra)
    extra = extra or {}
    extra.caseId, extra.originId, extra.members, extra.withOrigin = caseId, originId, members, true
    return newRun(extra)
end

local function relicRun(caseId, forms, members, extra)
    extra = extra or {}
    extra.caseId, extra.forms, extra.members = caseId, forms, members
    return newRun(extra)
end

local function checkFileRoundTrip(caseId, profile, draft, run)
    local raw = State.Export(profile, draft, run)
    check(caseId, "State.Export", type(raw) == "string" and #raw > 0, "导出内容为空")
    local writer = File(FILE_PATH, FILE_WRITE)
    check(caseId, "File(" .. FILE_PATH .. ",FILE_WRITE)", writer:IsOpen(), "验收导出文件无法打开")
    check(caseId, "File.WriteString", writer:WriteString(raw) == true, "真实文件 API 写入未返回 true")
    writer:Close()
    local reader = File(FILE_PATH, FILE_READ)
    check(caseId, "File(" .. FILE_PATH .. ",FILE_READ)", reader:IsOpen(), "验收导出文件回读无法打开")
    local roundTrip = reader:ReadString()
    reader:Close()
    check(caseId, "File.ReadString", roundTrip == raw, "导出文件回读内容与写入内容不一致")
    local candidate, message = State.PreflightImport(roundTrip)
    check(caseId, "State.PreflightImport", candidate ~= nil, message or "导出内容预检失败")
    check(caseId, "State.PreflightImport.artVersion", candidate.run.artVersion == "ink_v2_review", "导出预检丢失水墨版本")
end

local function testOriginPlain()
    local members = { memberSpec(1, "换种甲", 42, "basic", "farm"), memberSpec(2, "换种乙", 40, "basic", "farm") }
    local run, profile, draft = originRun("T14-origin-plain-seed", "plain", members)
    local initialGrain = run.grain
    check("T14-origin-plain-seed", "Origin.Execute(start)", Origin.Execute(run, "start", { memberId = 1 }), "plain 当前为 available，办理人需为耕作成年人且至少有1亩田")
    check("T14-origin-plain-seed", "Origin paid grain", Origin.Get(run).paid.grain == 4 and run.grain == initialGrain - 4, "接取换种未扣4石")
    advance("T14-origin-plain-seed", run, profile)
    check("T14-origin-plain-seed", "Origin.Tick.ready", Origin.Get(run).status == "ready" and run.grain >= initialGrain + 4, "真实耕作年度后未进入待选结算")
    check("T14-origin-plain-seed", "Origin.Execute(keep_seed)", Origin.Execute(run, "keep_seed"), "ready 状态未开放留种")
    local before = run.grain
    advance("T14-origin-plain-seed", run, profile)
    check("T14-origin-plain-seed", "OriginEffects.HouseholdGrain", run.lastLedger.originGrain == 2 and run.grain >= before, "两位实际耕作人重复或漏发留种增粮")
    check("T14-origin-plain-seed", "seed remainingUses", Origin.Get(run).benefits.seed.remainingUses == 2, "留种权益次数未扣减")
    validate("T14-origin-plain-seed", run, profile, draft)
    pass("origin.plain.keep_seed", "付4石→真实耕作1年收8石→留种付2石→实际年度增粮2且按户只结算一次")

    run, profile, draft = originRun("T14-origin-plain-share", "plain", members)
    local reputation = run.reputation
    check("T14-origin-plain-share", "Origin.Execute(start)", Origin.Execute(run, "start", { memberId = 1 }), "plain start")
    advance("T14-origin-plain-share", run, profile)
    check("T14-origin-plain-share", "Origin.Execute(share_seed)", Origin.Execute(run, "share_seed"), "ready 状态未开放分给邻人")
    check("T14-origin-plain-share", "share reputation", run.reputation == reputation + 4 and not Origin.Get(run).benefits.seed, "分种分支声望或权益错误")
    pass("origin.plain.share_seed", "真实收获后分给邻人，声望+4且不生成留种权益")

    run, profile, draft = originRun("T14-origin-plain-food", "plain", members)
    check("T14-origin-plain-food", "Origin.Execute(start)", Origin.Execute(run, "start", { memberId = 1 }), "plain start")
    advance("T14-origin-plain-food", run, profile)
    local foodBefore = run.grain
    check("T14-origin-plain-food", "Origin.Execute(keep_food)", Origin.Execute(run, "keep_food"), "ready 状态未开放留作家用")
    check("T14-origin-plain-food", "keep food", Origin.Get(run).status == "settled" and run.grain == foodBefore, "留作家用错误改变收获粮")
    pass("origin.plain.keep_food", "真实收获后保留8石家用，未附加权益")
end

local function testOriginArtisan()
    local members = { memberSpec(1, "修缮甲", 42, "craft", "craft"), memberSpec(2, "修缮乙", 40, "craft", "craft") }
    local run, profile, draft = originRun("T14-origin-artisan-cash", "artisan", members)
    local ruler = primary("T14-origin-artisan-cash", run, "ruler")
    check("T14-origin-artisan-cash", "Origin.Execute(start)", Origin.Execute(run, "start", { memberId = 1, attachedInstanceIds = { ruler.instanceId } }), "artisan start with usable ruler attachment")
    check("T14-origin-artisan-cash", "Origin.Execute(pause)", Origin.Execute(run, "pause"), "active artisan opportunity should pause")
    local paid = run.money
    check("T14-origin-artisan-cash", "Origin.Execute(resume)", Origin.Execute(run, "resume", { memberId = 2 }), "paused artisan opportunity should resume to another adult")
    check("T14-origin-artisan-cash", "resume no re-charge", run.money == paid, "resume changed money after initial fee")
    advance("T14-origin-artisan-cash", run, profile)
    check("T14-origin-artisan-cash", "Origin.Execute(take_cash)", Origin.Execute(run, "take_cash"), "artisan ready result cash branch")
    check("T14-origin-artisan-cash", "cash branch", Origin.Get(run).status == "settled" and run.originOpportunity.claims.take_cash == true, "cash branch did not settle")
    pass("origin.artisan.take_cash", "付8两→暂停保存语义内换办理人→真实手艺年度→返工料8并领报酬14")

    run, profile, draft = originRun("T14-origin-artisan-discount", "artisan", members)
    check("T14-origin-artisan-discount", "Origin.Execute(start)", Origin.Execute(run, "start", { memberId = 1 }), "artisan start")
    advance("T14-origin-artisan-discount", run, profile)
    check("T14-origin-artisan-discount", "Origin.Execute(take_discount)", Origin.Execute(run, "take_discount"), "artisan ready discount branch")
    local quote = Simulation.AssetQuote(run, "workshop")
    check("T14-origin-artisan-discount", "Simulation.AssetQuote", quote.price == 64 and quote.discount == 16, "作坊优惠报价未按一次16两计算")
    check("T14-origin-artisan-discount", "Simulation.BuyAsset", Simulation.BuyAsset(run, "workshop"), "带优惠的真实作坊购置失败")
    check("T14-origin-artisan-discount", "discount one-shot", not Origin.Get(run).benefits.workshop_discount.active and run.workshop == true, "作坊优惠未在真实购置后消费")
    pass("origin.artisan.take_discount", "真实结算领14两→作坊报价80减16→实际购置64两→优惠只消费一次")
end

local function testOriginMerchant()
    local members = { memberSpec(1, "旧账甲", 42, "trade", "trade"), memberSpec(2, "旧账乙", 40, "trade", "trade") }
    local run, profile, draft = originRun("T14-origin-merchant-settle", "merchant", members)
    local startMoney = run.money
    check("T14-origin-merchant-settle", "Origin.Execute(audit)", Origin.Execute(run, "audit", { memberId = 1 }), "merchant available audit")
    check("T14-origin-merchant-settle", "Origin.Execute(settle)", Origin.Execute(run, "settle"), "audited merchant debt should settle")
    check("T14-origin-merchant-settle", "settle net", run.money == startMoney + 10 and Origin.Get(run).status == "settled", "旧欠12减对账2的净额错误")
    pass("origin.merchant.settle", "真实对账付2两→即时回收12两→净增10两")

    run, profile, draft = originRun("T14-origin-merchant-renew", "merchant", members)
    check("T14-origin-merchant-renew", "Origin.Execute(audit)", Origin.Execute(run, "audit", { memberId = 1 }), "merchant audit")
    local beforeRenew = run.money
    check("T14-origin-merchant-renew", "Origin.Execute(renew)", Origin.Execute(run, "renew", { memberId = 2 }), "merchant renew")
    check("T14-origin-merchant-renew", "renew capital", run.money == beforeRenew - 12, "续单本金未扣12两")
    local preview = Economy.Preview(run)
    advance("T14-origin-merchant-renew", run, profile)
    check("T14-origin-merchant-renew", "renew settlement", run.money == preview.money + 30 and Origin.Get(run).status == "settled", "续单未分列返还本金、旧欠与利润")
    pass("origin.merchant.renew", "对账2两→续单投入12两→真实经商年度回收本金12、旧欠12、利润6")

    run, profile, draft = originRun("T14-origin-merchant-abandon", "merchant", members)
    check("T14-origin-merchant-abandon", "Origin.Execute(audit)", Origin.Execute(run, "audit", { memberId = 1 }), "merchant audit")
    check("T14-origin-merchant-abandon", "Origin.Execute(abandon)", Origin.Execute(run, "abandon"), "audited opportunity should expose abandon")
    check("T14-origin-merchant-abandon", "abandon no fallback", Origin.Get(run).status == "abandoned" and run.money == 78, "放弃后不应返还未领取旧欠")
    pass("origin.merchant.abandon", "已对账机会可永久放弃，已付对账费不返还")
end

local function testOriginScholar()
    local members = { memberSpec(1, "借卷甲", 42, "basic", "study"), memberSpec(2, "借卷乙", 40, "basic", "farm") }
    local run, profile, draft = originRun("T14-origin-scholar-return", "scholar", members)
    check("T14-origin-scholar-return", "Origin.Execute(borrow)", Origin.Execute(run, "borrow", { memberId = 1 }), "scholar reader must be study")
    local o = Origin.Get(run)
    check("T14-origin-scholar-return", "borrow accounting", run.money == 72 and o.deposit == 6 and o.dueAfterYear == 3, "整理费2与押金6未分列")
    advance("T14-origin-scholar-return", run, profile)
    check("T14-origin-scholar-return", "scroll first actual year", o.benefits.scroll.remainingUses == 1, "实际读书年度未消耗一次旧卷权益")
    setJob("T14-origin-scholar-return", run, 2, "study")
    check("T14-origin-scholar-return", "Origin.Execute(assign_reader)", Origin.Execute(run, "assign_reader", { memberId = 2 }), "在世合格读者可免费更换")
    setJob("T14-origin-scholar-return", run, 1, "farm")
    advance("T14-origin-scholar-return", run, profile, 2)
    local before = run.money
    check("T14-origin-scholar-return", "Origin.Execute(return)", Origin.Execute(run, "return"), "期限内归还旧卷")
    check("T14-origin-scholar-return", "return deposit", run.money == before + 6 and o.status == "returned" and not Origin.Execute(run, "return"), "归还未退全押金或重复归还成功")
    pass("origin.scholar.return", "借卷8两含押金6→实际阅读1次→免费换读者→期限内归还退6且不可重复")

    run, profile, draft = originRun("T14-origin-scholar-reclaim", "scholar", members)
    check("T14-origin-scholar-reclaim", "Origin.Execute(borrow)", Origin.Execute(run, "borrow", { memberId = 1 }), "scholar borrow")
    advance("T14-origin-scholar-reclaim", run, profile, 6)
    o = Origin.Get(run)
    check("T14-origin-scholar-reclaim", "late penalty", o.status == "reclaimed" and o.deposit == 0 and o.latePenalty == 6 and not o.benefits.scroll.active, "第6年末未完整扣押金并收回旧卷")
    check("T14-origin-scholar-reclaim", "reclaim return blocked", not Origin.Execute(run, "return"), "押金耗尽后归还动作不应再次结算")
    pass("origin.scholar.reclaim", "借卷到第4/5/6年逐年扣2两→押金清零→旧卷收回且权益失效")
end

local function testOriginMilitary()
    local members = { memberSpec(1, "护送甲", 42, "martial", "guard"), memberSpec(2, "护送乙", 40, "martial", "guard") }
    local run, profile, draft = originRun("T14-origin-military-safe", "military", members)
    check("T14-origin-military-safe", "Origin.Execute(safe)", Origin.Execute(run, "safe", { memberId = 1 }), "military safe route")
    local preview = Economy.Preview(run)
    advance("T14-origin-military-safe", run, profile)
    check("T14-origin-military-safe", "safe result", Origin.Get(run).status == "settled" and run.money == preview.money + 18, "稳路未返盘缠6并支付报酬12")
    pass("origin.military.safe", "稳路付6两→真实护卫年度→返6并领12，武艺+2")

    run, profile, draft = originRun("T14-origin-military-rush-success", "military", members, { rngSeed = 1 })
    check("T14-origin-military-rush-success", "Origin.Execute(rush)", Origin.Execute(run, "rush", { memberId = 1 }), "military rush route")
    local draw = Origin.Get(run).riskDraw
    local rngState = run.rngState
    check("T14-origin-military-rush-success", "rush fixed draw", draw ~= nil and run.rngState ~= draft.rngSeed, "急件接取未固定风险抽签")
    check("T14-origin-military-rush-success", "Origin.Execute(pause)", Origin.Execute(run, "pause"), "rush pause")
    check("T14-origin-military-rush-success", "Origin.Execute(resume)", Origin.Execute(run, "resume", { memberId = 2 }), "rush resume")
    check("T14-origin-military-rush-success", "draw preserved", Origin.Get(run).riskDraw == draw and run.rngState == rngState, "暂停换人改变风险抽签")
    preview = Economy.Preview(run)
    advance("T14-origin-military-rush-success", run, profile)
    check("T14-origin-military-rush-success", "rush success", Origin.Get(run).status == "settled" and run.money == preview.money + 32, "固定抽签低于年初成功率却未按成功结算")
    pass("origin.military.rush.success", "接急件固定抽签→暂停换人不重抽→真实年初条件判定→成功回款32")

    run, profile, draft = originRun("T14-origin-military-rush-failure", "military", members, { rngSeed = 2147483646 })
    check("T14-origin-military-rush-failure", "Origin.Execute(rush)", Origin.Execute(run, "rush", { memberId = 1 }), "military rush route")
    preview = Economy.Preview(run)
    local health = run.members[1].health
    advance("T14-origin-military-rush-failure", run, profile)
    check("T14-origin-military-rush-failure", "rush failure", Origin.Get(run).status == "settled_failure" and run.money == preview.money + 6 and run.members[1].health == health - 8, "固定高抽签未按失败退6并扣体魄")
    pass("origin.military.rush.failure", "急件高抽签真实失败→退未用盘缠6→净支出2→体魄-8、武艺+1")
end

local function testOriginGentry()
    local members = { memberSpec(1, "旧客甲", 42, "basic", "farm"), memberSpec(2, "旧客乙", 40, "basic", "study") }
    local run, profile, draft = originRun("T14-origin-gentry-study", "gentry", members)
    check("T14-origin-gentry-study", "Origin.Execute(start)", Origin.Execute(run, "start", { memberId = 1 }), "gentry start")
    advance("T14-origin-gentry-study", run, profile)
    local learner = run.members[2]
    local learnBefore = learner.stats.learn
    check("T14-origin-gentry-study", "Origin.Execute(study_referral)", Origin.Execute(run, "study_referral", { memberId = 2 }), "gentry study target")
    advance("T14-origin-gentry-study", run, profile)
    check("T14-origin-gentry-study", "study referral actual job", learner.stats.learn == learnBefore + 5 + 2 and Origin.Get(run).benefits.study_referral.remainingUses == 2, "求学引荐未只在实际付费读书年追加2")
    pass("origin.gentry.study_referral", "1个真实工作年后固定求学对象→实际读书年度学识基础增长外再+2")

    local workMembers = { memberSpec(1, "旧客丙", 42, "basic", "farm"), memberSpec(2, "旧客丁", 40, "craft", "craft") }
    run, profile, draft = originRun("T14-origin-gentry-work", "gentry", workMembers)
    check("T14-origin-gentry-work", "Origin.Execute(start)", Origin.Execute(run, "start", { memberId = 1 }), "gentry start")
    advance("T14-origin-gentry-work", run, profile)
    local worker = run.members[2]
    local moneyBefore = run.money
    check("T14-origin-gentry-work", "Origin.Execute(work_referral)", Origin.Execute(run, "work_referral", { memberId = 2 }), "gentry work target")
    advance("T14-origin-gentry-work", run, profile)
    check("T14-origin-gentry-work", "work referral actual job", worker.jobId == "craft" and worker.stats.skill >= 52 and run.lastLedger.originIncome == 6, "谋生引荐未在实际手艺年追加6两")
    check("T14-origin-gentry-work", "work referral balance", run.money > moneyBefore, "谋生引荐年度实际收入未进入公库")
    pass("origin.gentry.work_referral", "固定手艺谋生对象→真实手艺年度追加6两→4年期限与次数记录可追溯")
end

local function testRelicGenealogy()
    local members = { memberSpec(1, "族谱甲", 42, "scholar", "study", "learn"), memberSpec(2, "族谱乙", 40, "basic", "farm") }
    local run, profile, draft = relicRun("T14-relic-genealogy-fast", { "genealogy.1" }, members)
    local book = primary("T14-relic-genealogy-fast", run, "genealogy")
    startRelic("T14-relic-genealogy-fast", run, profile, "genealogy.trace_missing_page", { instanceId = book.instanceId, executorId = 1, route = "fast" })
    advance("T14-relic-genealogy-fast", run, profile)
    check("T14-relic-genealogy-fast", "ready defer", Relics.Start(run, profile, "genealogy.bind_verified_pages", { instanceId = book.instanceId, executorId = 1, branch = "defer" }), "ready 结果应允许暂存")
    check("T14-relic-genealogy-fast", "defer keeps ready", book.formId == "genealogy.1" and book.taskId ~= nil, "暂存分支错误升级或释放 ready")
    startRelic("T14-relic-genealogy-fast", run, profile, "genealogy.bind_verified_pages", { instanceId = book.instanceId, executorId = 1, branch = "restore" })
    check("T14-relic-genealogy-fast", "restore same instance", book.formId == "genealogy.2" and #run.relicInstances == 1, "补入分支创建第二本族谱或未升级原实例")
    pass("relic.genealogy.trace.fast.restore.defer", "快查1年→ready暂存→同实例补入升二阶，暂存不重复扣费")

    run, profile, draft = relicRun("T14-relic-genealogy-slow", { "genealogy.1" }, members)
    book = primary("T14-relic-genealogy-slow", run, "genealogy")
    startRelic("T14-relic-genealogy-slow", run, profile, "genealogy.trace_missing_page", { instanceId = book.instanceId, executorId = 1, route = "slow" })
    advance("T14-relic-genealogy-slow", run, profile)
    check("T14-relic-genealogy-slow", "slow remains active", book.taskId ~= nil and book.formId == "genealogy.1", "慢查第一年提前 ready")
    advance("T14-relic-genealogy-slow", run, profile)
    check("T14-relic-genealogy-slow", "slow ready", book.taskId ~= nil, "慢查第二年没有形成 ready")
    startRelic("T14-relic-genealogy-slow", run, profile, "genealogy.bind_verified_pages", { instanceId = book.instanceId, executorId = 1, branch = "restore" })
    pass("relic.genealogy.trace.slow", "慢查4两/2年真实完成并进入同实例补入")

    run, profile, draft = relicRun("T14-relic-genealogy-branch", { "genealogy.2" }, members)
    book = primary("T14-relic-genealogy-branch", run, "genealogy")
    startRelic("T14-relic-genealogy-branch", run, profile, "genealogy.verify_branch", { instanceId = book.instanceId, executorId = 1 })
    advance("T14-relic-genealogy-branch", run, profile)
    local count = #run.members
    startRelic("T14-relic-genealogy-branch", run, profile, "genealogy.invite_branch", { instanceId = book.instanceId, executorId = 1 })
    check("T14-relic-genealogy-branch", "invite branch", #run.members == count + 1 and run.members[#run.members].externalLineage ~= nil, "旁支核实后未生成真实可安排成员")
    pass("relic.genealogy.verify.invite", "核对旁支1年固定候选→即时付12两接回真实成员")

    run, profile, draft = relicRun("T14-relic-genealogy-chronicle", { "genealogy.3" }, members)
    book = primary("T14-relic-genealogy-chronicle", run, "genealogy")
    local reputation = run.reputation
    startRelic("T14-relic-genealogy-chronicle", run, profile, "genealogy.compile_chronicle", { instanceId = book.instanceId, executorId = 1 })
    advance("T14-relic-genealogy-chronicle", run, profile)
    check("T14-relic-genealogy-chronicle", "compile outcome", book.formId == "genealogy.3" and run.reputation == reputation + 12, "编史未增加12点声望")
    check("T14-relic-genealogy-chronicle", "compile snapshot", factByKind(run, "family_chronicle_compiled") ~= nil and factByKind(run, "family_chronicle_compiled").factsSnapshot ~= nil, "家史事实快照未写入")
    pass("relic.genealogy.compile", "三阶族谱真实编史1年→声望+12→保存当时事实快照")
end

local function matureGenealogy()
    local members = { memberSpec(1, "续谱甲", 42, "scholar", "study", "learn"), memberSpec(2, "续谱乙", 40, "trade", "trade") }
    local run, profile, draft = relicRun("T14-relic-genealogy-upgrade", { "genealogy.2" }, members)
    local book = primary("T14-relic-genealogy-upgrade", run, "genealogy")
    check("T14-relic-genealogy-upgrade", "Simulation.Adopt", Simulation.Adopt(run, 1), "需要真实第二代族人")
    for year = 1, 12 do
        if year == 7 then setJob("T14-relic-genealogy-upgrade", run, 3, "apprentice") end
        advance("T14-relic-genealogy-upgrade", run, profile)
        if run.yearIndex == 1 then
            check("T14-relic-genealogy-upgrade", "Simulation.AppointLeader(2)", Simulation.AppointLeader(run, 2, "T14真实交接"), "第一项有效交接失败")
        end
    end
    setJob("T14-relic-genealogy-upgrade", run, 3, "study")
    check("T14-relic-genealogy-upgrade", "Simulation.AppointLeader(3)", Simulation.AppointLeader(run, 3, "T14第二项真实交接"), "第二项有效交接失败")
    check("T14-relic-genealogy-upgrade", "RelicSystem.AssignUser", Relics.AssignUser(run, book.instanceId, 3), "第二代合格修谱人无法接手")
    advance("T14-relic-genealogy-upgrade", run, profile)
    local quote = Relics.Quote(run, "genealogy.upgrade_3", { instanceId = book.instanceId, executorId = 1 })
    if not quote.allowed then
        local terms = {}
        for _, term in ipairs(run.leaderTerms or {}) do table.insert(terms, tostring(term.memberId) .. ":" .. tostring(term.realHandover) .. ":" .. tostring(term.endYear)) end
        fail("T14-relic-genealogy-upgrade", "RelicSystem.Quote(genealogy.upgrade_3)", table.concat(quote.reasons or {}, "；"), "leaderTerms=" .. table.concat(terms, ","))
    end
    check("T14-relic-genealogy-upgrade", "upgrade prerequisites", quote.workYears == 1 and #run.relicUseFacts >= 2, "真实年度未形成跨代族谱使用事实")
    startRelic("T14-relic-genealogy-upgrade", run, profile, "genealogy.upgrade_3", { instanceId = book.instanceId, executorId = 1 })
    advance("T14-relic-genealogy-upgrade", run, profile)
    check("T14-relic-genealogy-upgrade", "upgrade result", book.formId == "genealogy.3", "族谱续修未升三阶")
    pass("relic.genealogy.upgrade_3", "真实经营13年→两项有效交接→两代实际使用→续修1年升三阶")
end

local function testRelicRulerPlan()
    local members = { memberSpec(1, "木尺甲", 42, "craft", "craft", "skill"), memberSpec(2, "木尺乙", 40, "basic", "farm") }
    local run, profile, draft = relicRun("T14-relic-ruler-routes", { "ruler.1" }, members)
    local ruler = primary("T14-relic-ruler-routes", run, "ruler")
    startRelic("T14-relic-ruler-routes", run, profile, "ruler.trace_mark", { instanceId = ruler.instanceId, executorId = 1, route = "fast" })
    advance("T14-relic-ruler-routes", run, profile)
    check("T14-relic-ruler-routes", "trace fast", ruler.formId == "ruler.2", "快查匠号未校准一阶木尺")
    startRelic("T14-relic-ruler-routes", run, profile, "ruler.copy_plan", { instanceId = ruler.instanceId, executorId = 1 })
    local plan = primary("T14-relic-ruler-routes", run, "plan")
    check("T14-relic-ruler-routes", "copy plan", plan.formId == "plan.1" and not Relics.Start(run, profile, "ruler.copy_plan", { instanceId = ruler.instanceId, executorId = 1 }), "誊图重复取得没有被拒绝")
    pass("relic.ruler.trace.fast.copy", "快查1年校准原木尺→即时誊出一阶营造图→同线重复取得拒绝")

    run, profile, draft = relicRun("T14-relic-ruler-slow", { "ruler.1" }, members)
    ruler = primary("T14-relic-ruler-slow", run, "ruler")
    startRelic("T14-relic-ruler-slow", run, profile, "ruler.trace_mark", { instanceId = ruler.instanceId, executorId = 1, route = "slow" })
    advance("T14-relic-ruler-slow", run, profile, 2)
    check("T14-relic-ruler-slow", "trace slow", ruler.formId == "ruler.2", "慢查匠号未在第二年校准")
    pass("relic.ruler.trace.slow", "慢查4两/2年真实校准并留下图样线索")

    local longMembers = { memberSpec(1, "长线甲", 42, "craft", "craft", "skill"), memberSpec(2, "长线乙", 40, "basic", "farm") }
    run, profile, draft = relicRun("T14-relic-ruler-plan-long", { "ruler.2", "plan.1" }, longMembers, { relicUsers = { ["ruler.2"] = 1, ["plan.1"] = 1 } })
    ruler, plan = primary("T14-relic-ruler-plan-long", run, "ruler"), primary("T14-relic-ruler-plan-long", run, "plan")
    check("T14-relic-ruler-plan-long", "Simulation.Adopt", Simulation.Adopt(run, 1), "需要真实第二代匠人")
    startRelic("T14-relic-ruler-plan-long", run, profile, "plan.small_repair", { instanceId = plan.instanceId, executorId = 1, attachedInstanceIds = { plan.instanceId, ruler.instanceId } })
    advance("T14-relic-ruler-plan-long", run, profile)
    for _ = 1, 3 do advance("T14-relic-ruler-plan-long", run, profile) end
    startRelic("T14-relic-ruler-plan-long", run, profile, "plan.small_repair", { instanceId = plan.instanceId, executorId = 1, attachedInstanceIds = { plan.instanceId, ruler.instanceId } })
    advance("T14-relic-ruler-plan-long", run, profile)
    for year = 6, 13 do
        if year == 7 then setJob("T14-relic-ruler-plan-long", run, 3, "apprentice") end
        if year == 13 then
            setJob("T14-relic-ruler-plan-long", run, 3, "craft")
            check("T14-relic-ruler-plan-long", "RelicSystem.AssignUser(ruler)", Relics.AssignUser(run, ruler.instanceId, 3), "第二代木尺使用人无法接手")
            check("T14-relic-ruler-plan-long", "RelicSystem.AssignUser(plan)", Relics.AssignUser(run, plan.instanceId, 3), "第二代营造图使用人无法接手")
        end
        advance("T14-relic-ruler-plan-long", run, profile)
    end
    local rulerQuote = quoteRelic("T14-relic-ruler-plan-long", run, "ruler.upgrade_3", { instanceId = ruler.instanceId, executorId = 1 })
    check("T14-relic-ruler-plan-long", "ruler mature prerequisites", rulerQuote.allowed and #run.relicProjectFacts >= 4, "两项真实工程未为木尺和营造图分别留下工程事实")
    startRelic("T14-relic-ruler-plan-long", run, profile, "ruler.upgrade_3", { instanceId = ruler.instanceId, executorId = 1 })
    advance("T14-relic-ruler-plan-long", run, profile)
    check("T14-relic-ruler-plan-long", "ruler upgrade", ruler.formId == "ruler.3", "木尺重整未升三阶")
    startRelic("T14-relic-ruler-plan-long", run, profile, "plan.upgrade_2", { instanceId = plan.instanceId, executorId = 1 })
    advance("T14-relic-ruler-plan-long", run, profile)
    check("T14-relic-ruler-plan-long", "plan upgrade2", plan.formId == "plan.2", "营造图增订未升二阶")
    startRelic("T14-relic-ruler-plan-long", run, profile, "plan.upgrade_3", { instanceId = plan.instanceId, executorId = 1 })
    advance("T14-relic-ruler-plan-long", run, profile)
    check("T14-relic-ruler-plan-long", "plan upgrade3", plan.formId == "plan.3", "营造图传世未升三阶")
    local beforeBridgeMoney, beforeBridgeRep = run.money, run.reputation
    startRelic("T14-relic-ruler-plan-long", run, profile, "plan.bridge", { instanceId = plan.instanceId, executorId = 1 })
    advance("T14-relic-ruler-plan-long", run, profile, 2)
    local bridgeTransactions = {}
    for _, entry in ipairs(run.relicTransactions or {}) do table.insert(bridgeTransactions, tostring(entry.actionId) .. ":" .. tostring(entry.money)) end
    check("T14-relic-ruler-plan-long", "plan bridge", transactionSum(run, "plan.bridge") == 40 and run.reputation == beforeBridgeRep + 10, "status=" .. tostring(run.relicTasks[#run.relicTasks].status) .. " tx=" .. table.concat(bridgeTransactions, ","))
    pass("relic.ruler.upgrade3.plan.upgrade2.upgrade3.bridge", "真实跨代使用与两项工程→木尺三阶→营造图二阶/三阶→修桥2年结算")

    run, profile, draft = relicRun("T14-relic-ruler-teach", { "ruler.3" }, {
        memberSpec(1, "传艺甲", 42, "craft", "craft", "skill"), memberSpec(2, "传艺乙", 12, "basic", "apprentice")
    })
    local master = primary("T14-relic-ruler-teach", run, "ruler")
    advance("T14-relic-ruler-teach", run, profile, 3)
    local masterBefore = run.members[1].stats.skill
    local learnerBefore = run.members[2].stats.skill
    startRelic("T14-relic-ruler-teach", run, profile, "ruler.teach_successor", { instanceId = master.instanceId, executorId = 1, learnerId = 2 })
    advance("T14-relic-ruler-teach", run, profile)
    local teachFact = factByKind(run, "relic_apprenticeship")
    check("T14-relic-ruler-teach", "teach outcome", run.members[1].stats.skill >= masterBefore + 1 and run.members[2].stats.skill >= learnerBefore + 6 and teachFact ~= nil and teachFact.masterGain == 1 and teachFact.learnerGain == 6, "师徒传艺成长未分别写入师父和学徒")
    pass("relic.ruler.teach_successor", "真实师父手艺达到55→1年传艺→学徒手艺+6、师父+1且不增加职业人年")
end

local function testRelicLetter()
    local members = { memberSpec(1, "家书甲", 42, "basic", "home"), memberSpec(2, "家书乙", 40, "basic", "home") }
    local run, profile, draft = relicRun("T14-relic-letter-personal", { "letter.1" }, members)
    local letter = primary("T14-relic-letter-personal", run, "letter")
    startRelic("T14-relic-letter-personal", run, profile, "letter.deliver", { instanceId = letter.instanceId, executorId = 1, route = "personal" })
    advance("T14-relic-letter-personal", run, profile)
    startRelic("T14-relic-letter-personal", run, profile, "letter.confirm_delivery", { instanceId = letter.instanceId, executorId = 1 })
    check("T14-relic-letter-personal", "confirm delivery", letter.formId == "letter.2", "个人寻人未升二阶")
    pass("relic.letter.deliver.personal.confirm", "个人递信1年→ready确认交付→同实例升二阶")

    run, profile, draft = relicRun("T14-relic-letter-entrusted", { "letter.1" }, members)
    letter = primary("T14-relic-letter-entrusted", run, "letter")
    startRelic("T14-relic-letter-entrusted", run, profile, "letter.deliver", { instanceId = letter.instanceId, executorId = 1, route = "entrusted" })
    advance("T14-relic-letter-entrusted", run, profile, 2)
    startRelic("T14-relic-letter-entrusted", run, profile, "letter.confirm_delivery", { instanceId = letter.instanceId, executorId = 1 })
    check("T14-relic-letter-entrusted", "entrusted route", letter.formId == "letter.2", "托付递信两年未形成交付结果")
    pass("relic.letter.deliver.entrusted", "托付递信3两/2年真实完成并可确认交付")

    local promiseMembers = { memberSpec(1, "托付甲", 42, "basic", "home"), memberSpec(2, "托付乙", 40, "basic", "home") }
    run, profile, draft = relicRun("T14-relic-letter-books", { "letter.2" }, promiseMembers)
    letter = primary("T14-relic-letter-books", run, "letter")
    local jadeCount = #run.relicInstances
    local reputation = run.reputation
    startRelic("T14-relic-letter-books", run, profile, "letter.fulfil_promise", { instanceId = letter.instanceId, executorId = 1, route = "books" })
    advance("T14-relic-letter-books", run, profile)
    check("T14-relic-letter-books", "promise books", letter.formId == "letter.3" and #run.relicInstances == jadeCount + 1 and run.reputation == reputation + 6, "购书履约未升三阶、加声望或赠玉")
    pass("relic.letter.fulfil.books", "购书路线真实工作1年→家书三阶→声望+6→同线赠一阶玉佩")

    run, profile, draft = relicRun("T14-relic-letter-grain", { "letter.2" }, promiseMembers)
    letter = primary("T14-relic-letter-grain", run, "letter")
    local grainBefore = run.grain
    startRelic("T14-relic-letter-grain", run, profile, "letter.fulfil_promise", { instanceId = letter.instanceId, executorId = 1, route = "grain" })
    check("T14-relic-letter-grain", "promise grain cost", run.grain == grainBefore - 4, "送粮履约未在接取时扣4石")
    advance("T14-relic-letter-grain", run, profile)
    check("T14-relic-letter-grain", "promise grain outcome", letter.formId == "letter.3" and run.flags.promiseKept, "送粮履约未完成")
    pass("relic.letter.fulfil.grain", "送粮路线接取扣4石→真实工作1年→家书三阶与旧约履行事实")

    for _, branch in ipairs({ "silver", "grain" }) do
        local caseId = "T14-relic-letter-aid-" .. branch
        run, profile, draft = relicRun(caseId, { "letter.3" }, {
            memberSpec(1, "渡难甲", 42, "basic", "farm"), memberSpec(2, "渡难乙", 40, "basic", "home")
        }, { money = 10, grain = 0 })
        letter = primary(caseId, run, "letter")
        local moneyBefore, grainBeforeAid = run.money, run.grain
        startRelic(caseId, run, profile, "letter.ask_aid", { instanceId = letter.instanceId, executorId = 1, branch = branch })
        advance(caseId, run, profile)
        if branch == "silver" then
            check(caseId, "aid silver", transactionSum(run, "letter.ask_aid") == 12, "援银分支未写入援银12两")
        else
            check(caseId, "aid grain", transactionGrainSum(run, "letter.ask_aid") == 8, "援粮分支未写入援粮8石")
        end
        pass("relic.letter.ask_aid." .. branch, "低银低粮条件下实际邮递1年→" .. branch .. "分支援助到账且只成功一次")
    end
end

local function testRelicPlanBuyAndRepair()
    local members = { memberSpec(1, "购图甲", 42, "craft", "craft", "skill"), memberSpec(2, "购图乙", 40, "craft", "craft", "skill") }
    local run, profile, draft = relicRun("T14-relic-plan-buy", {}, members)
    advance("T14-relic-plan-buy", run, profile, 3)
    check("T14-relic-plan-buy", "plan buy quote", quoteRelic("T14-relic-plan-buy", run, "plan.buy_old_drawing", { executorId = 1 }).allowed, "累计手艺人年与手艺要求未形成")
    startRelic("T14-relic-plan-buy", run, profile, "plan.buy_old_drawing", { executorId = 1 })
    local plan = primary("T14-relic-plan-buy", run, "plan")
    check("T14-relic-plan-buy", "plan buy result", plan.formId == "plan.1", "职业路线购图未即时取得一阶营造图")
    pass("relic.plan.buy_old_drawing", "真实手艺谋生人年达到6且手艺55→即时购入一阶营造图")

    run, profile, draft = relicRun("T14-relic-plan-small-repair", { "plan.1" }, members)
    plan = primary("T14-relic-plan-small-repair", run, "plan")
    local skillBefore = State.FindMember(run.members, 1).stats.skill
    startRelic("T14-relic-plan-small-repair", run, profile, "plan.small_repair", { instanceId = plan.instanceId, executorId = 1, attachedInstanceIds = { plan.instanceId } })
    advance("T14-relic-plan-small-repair", run, profile)
    local skillAfter = State.FindMember(run.members, 1).stats.skill
    local repairQuote = Relics.Quote(run, "plan.small_repair", { instanceId = plan.instanceId, executorId = 1 })
    local repairFact = nil
    for _, fact in ipairs(run.facts or {}) do
        if fact.kind == "relic_task_settled" and fact.actionId == "plan.small_repair" then repairFact = fact; break end
    end
    local repairOk = transactionSum(run, "plan.small_repair") == 18 and skillAfter >= skillBefore + 2 and repairFact and repairFact.skillGain == 2 and not repairQuote.allowed
    if not repairOk then
        recordDefect("relic.plan.small_repair", "RelicSystem.Start(plan.small_repair) -> Simulation.AdvanceYear -> RelicOutcomes.Apply(plan.small_repair)", "正式行动说明要求办理人手艺+2；实际手艺" .. tostring(skillBefore) .. "->" .. tostring(skillAfter) .. "，到账交易" .. tostring(transactionSum(run, "plan.small_repair")) .. "两，冷却已写入", "两名42/40岁craft成员、plan.1、executorId=1承接旧图活计后推进1个经营年度")
    else
        pass("relic.plan.small_repair", "支付8两→真实手艺年度成长外写入手艺+2→到账18两并记录净报酬10，冷却3年")
    end
end

local function maturePlan(caseId, branch)
    local members = { memberSpec(1, "营造甲", 42, "craft", "craft", "skill"), memberSpec(2, "营造乙", 40, "basic", "farm") }
    local run, profile, draft = relicRun(caseId, { "plan.1" }, members)
    local plan = primary(caseId, run, "plan")
    check(caseId, "Simulation.Adopt", Simulation.Adopt(run, 1), "需要真实第二代营造人")
    startRelic(caseId, run, profile, "plan.small_repair", { instanceId = plan.instanceId, executorId = 1, attachedInstanceIds = { plan.instanceId } })
    advance(caseId, run, profile)
    for _ = 1, 3 do advance(caseId, run, profile) end
    startRelic(caseId, run, profile, "plan.small_repair", { instanceId = plan.instanceId, executorId = 1, attachedInstanceIds = { plan.instanceId } })
    advance(caseId, run, profile)
    for year = 6, 13 do
        if year == 7 then setJob(caseId, run, 3, "apprentice") end
        if year == 13 then
            setJob(caseId, run, 3, "craft")
            check(caseId, "RelicSystem.AssignUser", Relics.AssignUser(run, plan.instanceId, 3), "第二代营造图使用人无法接手")
        end
        advance(caseId, run, profile)
    end
    startRelic(caseId, run, profile, "plan.upgrade_2", { instanceId = plan.instanceId, executorId = 1 })
    advance(caseId, run, profile)
    check(caseId, "plan.upgrade_2", plan.formId == "plan.2", "营造图未升二阶")
    startRelic(caseId, run, profile, "plan.upgrade_3", { instanceId = plan.instanceId, executorId = 1 })
    advance(caseId, run, profile)
    check(caseId, "plan.upgrade_3", plan.formId == "plan.3", "营造图未升三阶")
    if branch == "bridge" then
        local money, reputation = run.money, run.reputation
        startRelic(caseId, run, profile, "plan.bridge", { instanceId = plan.instanceId, executorId = 1 })
        advance(caseId, run, profile, 2)
        check(caseId, "plan.bridge", transactionSum(run, "plan.bridge") == 40 and run.reputation == reputation + 10, "修桥未写入本金24与净报酬16及声望10")
    end
    return run, profile, draft, plan
end

local function testRelicJade()
    for _, branch in ipairs({ "heirloom", "alliance" }) do
        local caseId = "T14-relic-jade-" .. branch
        local members = { memberSpec(1, "玉佩甲", 42, "basic", "home"), memberSpec(2, "玉佩乙", 40, "basic", "home") }
        local run, profile, draft = relicRun(caseId, { "jade.1" }, members)
        local jade = primary(caseId, run, "jade")
        startRelic(caseId, run, profile, "jade.verify_origin", { instanceId = jade.instanceId, executorId = 1 })
        advance(caseId, run, profile)
        startRelic(caseId, run, profile, "jade.meet", { instanceId = jade.instanceId, executorId = 1 })
        advance(caseId, run, profile)
        local reputation = run.reputation
        startRelic(caseId, run, profile, "jade.choose_final_form", { instanceId = jade.instanceId, executorId = 1, branch = branch })
        if branch == "heirloom" then
            check(caseId, "jade heirloom", jade.formId == "jade.3.heirloom" and run.reputation == reputation + 8, "合璧传家分支未升终形或加声望")
        else
            check(caseId, "jade alliance", jade.formId == "jade.3.alliance" and run.reputation == reputation, "各执半佩分支错误增加声望")
            local quote = Simulation.MigrationQuote(run, "mountain")
            check(caseId, "Simulation.MigrationQuote", quote.discount == 8 and quote.cost == quote.baseCost - 8, "各执半佩迁居优惠未形成")
            local moneyBeforeMove = run.money
            check(caseId, "Simulation.MoveFamily", Simulation.MoveFamily(run, "mountain"), "真实迁居执行失败")
            check(caseId, "migration discount", run.placeId == "mountain" and run.metrics.migrations == 1 and run.money == moneyBeforeMove - quote.cost, "迁居状态或优惠后扣款未写入")
        end
        pass("relic.jade." .. branch, "核实1年→相认1年→终形" .. branch .. "分支连续结算")
    end
end

local function matureNotes(caseId, branch)
    local members = { memberSpec(1, "医案甲", 42, "medical", "doctor", "medicine"), memberSpec(2, "医案乙", 40, "basic", "farm") }
    local run, profile, draft = relicRun(caseId, {}, members)
    check(caseId, "Simulation.Adopt", Simulation.Adopt(run, 1), "需要真实第二代医者")
    advance(caseId, run, profile, 6)
    check(caseId, "notes.accept quote", quoteRelic(caseId, run, "notes.accept_old_cases", { executorId = 1 }).allowed, "六个实际行医人年或医术55未形成")
    startRelic(caseId, run, profile, "notes.accept_old_cases", { executorId = 1 })
    local notes = primary(caseId, run, "notes")
    startRelic(caseId, run, profile, "notes.record_case", { instanceId = notes.instanceId, executorId = 1 })
    advance(caseId, run, profile)
    for _ = 1, 2 do advance(caseId, run, profile) end
    startRelic(caseId, run, profile, "notes.record_case", { instanceId = notes.instanceId, executorId = 1 })
    advance(caseId, run, profile)
    for year = 10, 13 do
        if year == 12 then
            setJob(caseId, run, 3, "medical")
            check(caseId, "RelicSystem.AssignUser(notes)", Relics.AssignUser(run, notes.instanceId, 3), "第二代医案使用人无法接手")
        end
        advance(caseId, run, profile)
    end
    startRelic(caseId, run, profile, "notes.upgrade_2", { instanceId = notes.instanceId, executorId = 1 })
    advance(caseId, run, profile)
    check(caseId, "notes.upgrade_2", notes.formId == "notes.2", "医案未升二阶")
    startRelic(caseId, run, profile, "notes.upgrade_3", { instanceId = notes.instanceId, executorId = 1, branch = branch })
    advance(caseId, run, profile)
    check(caseId, "notes.upgrade_3", notes.formId == "notes.3." .. branch, "医案三阶分支未按选择生成")
    if branch == "public" then
        local reputation = run.reputation
        startRelic(caseId, run, profile, "notes.public_clinic", { instanceId = notes.instanceId, executorId = 1 })
        advance(caseId, run, profile)
        check(caseId, "notes.public_clinic", run.reputation == reputation + 8, "公开义诊未增加声望8")
    end
    return run, profile, draft, notes
end

local function testRelicNotes()
    local run, profile, draft, notes = matureNotes("T14-relic-notes-private", "private")
    check("T14-relic-notes-private", "notes private complete", notes.formId == "notes.3.private", "家传医案分支未完成")
    pass("relic.notes.private", "真实6年行医门槛→两例实际病例与冷却→跨代使用→医案家传三阶")
    run, profile, draft, notes = matureNotes("T14-relic-notes-public", "public")
    check("T14-relic-notes-public", "notes public complete", notes.formId == "notes.3.public", "刊行医案分支未完成")
    pass("relic.notes.public.clinic", "同一真实病例链→刊行三阶→公开义诊1年声望+8")
end

local function testPersistence(caseId)
    State.UseVerificationStorage("origin")
    local run, profile, draft = relicRun(caseId, { "ruler.1" }, {
        memberSpec(1, "文件甲", 42, "craft", "craft", "skill"), memberSpec(2, "文件乙", 40, "basic", "farm")
    })
    startRelic(caseId, run, profile, "ruler.trace_mark", { instanceId = primary(caseId, run, "ruler").instanceId, executorId = 1, route = "fast" })
    local saved, message = State.Save(profile, draft, run)
    check(caseId, "State.Save", saved, message or "真实存档保存失败")
    local loaded, loadMessage = State.Load()
    check(caseId, "State.Load", loaded ~= nil, loadMessage or "真实存档读取失败")
    check(caseId, "State.Load continuity", loaded.run.relicTasks[1].actionId == "ruler.trace_mark", "保存读取后进行中的正式任务丢失")
    checkFileRoundTrip(caseId, loaded.profile, loaded.draft, loaded.run)
    pass("persistence.real-file-api", "State.Save/Load真实交替存档→独立T14导出文件写入回读→PreflightImport通过")
end

function T14.RunDomain()
    defects = {}
    check("T14-index", "RelicDefinitions.Actions", #RelicDefinitions.Actions == 27, "当前正式行动清单数量不是27")
    testOriginPlain()
    testOriginArtisan()
    testOriginMerchant()
    testOriginScholar()
    testOriginMilitary()
    testOriginGentry()
    testRelicGenealogy()
    matureGenealogy()
    testRelicRulerPlan()
    testRelicLetter()
    testRelicPlanBuyAndRepair()
    maturePlan("T14-relic-plan-mature", "bridge")
    testRelicJade()
    testRelicNotes()
    if #defects == 0 then
        pass("T14-matrix", "六项背景机会所有结果分支与信物27项行动均走正式模块和真实年度结算")
    else
        print(PREFIX .. " COVERAGE origin=all-six-families relic_actions=27 executed=all defects=" .. tostring(#defects))
        print(PREFIX .. " END domain=failed defects=" .. tostring(#defects))
    end
    return #defects == 0
end

function T14.Run()
    local domainPassed = T14.RunDomain()
    testPersistence("T14-persistence")
    print(PREFIX .. " COMPLETE domain=" .. (domainPassed and "passed" or "failed") .. " file_api=passed storage=jiaye_origin_verification plus " .. FILE_PATH)
end

function T14.Start()
    State.UseVerificationStorage("t14")
    T14.Run()
end

function T14.Stop()
end

function Start() T14.Start() end

function Stop() T14.Stop() end

return T14
