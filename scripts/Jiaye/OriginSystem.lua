local Data = require "Jiaye.Data"
local State = require "Jiaye.State"
local OriginState = require "Jiaye.OriginState"
local RelicState = require "Jiaye.RelicState"
local RelicSystem = require "Jiaye.RelicSystem"

local O = {}

function O.Get(run)
    return run and run.originRulesVersion == OriginState.VERSION and run.originOpportunity or nil
end

local function Member(run, id) return State.FindMember(run.members, id) end
local function Alive(member) return member and member.alive ~= false end
local function Has(ids, id)
    for _, value in ipairs(ids or {}) do if value == id then return true end end
    return false
end
local function Project(run, o) return o.projectId and (run.relicExternalProjects or {})[o.projectId] end
local function Working(o) return o.status == "active" and o.sourceOriginId ~= "scholar" end

local function Fact(run, outcome, text, memberId)
    local o = assert(O.Get(run))
    return State.AddFact(run, "origin", text, memberId and { memberId } or {}, {
        opportunityId = o.id, instanceId = o.instanceId, stageId = o.stage,
        outcome = outcome, yearIndex = run.yearIndex,
    })
end

local function Flow(run, category, money, grain, description, claimKey)
    local o = assert(O.Get(run))
    run.money = run.money + money; run.grain = run.grain + grain
    assert(run.money >= 0 and run.grain >= 0, "背景机会支出超过现有钱粮。")
    local entry = { category = category, money = money, grain = grain, description = description,
        opportunityId = o.id, instanceId = o.instanceId, stageId = o.stage, claimKey = claimKey,
        memberId = o.actorId or o.readerId, year = run.calendar, yearIndex = run.yearIndex }
    table.insert(run.originTransactions, entry)
    return entry
end

local function Benefit(run, kind, amount, uses, memberId, window)
    local o = assert(O.Get(run))
    o.benefits[kind] = { kind = kind, amount = amount, remainingUses = uses, memberId = memberId,
        firstEligibleYear = run.yearIndex + 1, expiresAfterYear = window and run.yearIndex + window,
        active = true, sourceOpportunityInstanceId = o.instanceId }
end

local labels = { start = "接下这件事", audit = "支付2两，对清旧账", settle = "收回12两，结清旧账", renew = "再付12两，续做一单",
    borrow = "支付8两，借入旧卷", ["return"] = "归还旧卷", assign_reader = "更换读者", safe = "走稳路", rush = "接急件",
    keep_seed = "花2石留下种", share_seed = "花2石分给邻人", keep_food = "留作家用", take_cash = "领取22两工钱",
    take_discount = "领取14两与作坊优惠", study_referral = "引荐求学", work_referral = "引荐谋生",
    pause = "暂停办理", resume = "继续办理", abandon = "放弃本次机会" }

function O.Actions(run)
    local o, result = O.Get(run), {}
    if not o or run.ending then return result end
    local function Add(id, kind, attachments)
        table.insert(result, { id = id, label = labels[id], inputKind = kind or "none", attachments = attachments or false })
    end
    local origin = o.sourceOriginId
    if o.status == "available" then
        if origin == "merchant" then Add("audit", "adult")
        elseif origin == "scholar" then Add("borrow", "study")
        elseif origin == "military" then Add("safe", "adult"); Add("rush", "adult")
        else Add("start", "adult", origin == "artisan") end
    elseif o.status == "active" and origin == "scholar" then
        Add("return"); Add("assign_reader", "study")
    elseif Working(o) then Add("pause"); Add("abandon")
    elseif o.status == "paused" or o.status == "paused_actor" then Add("resume", "adult"); Add("abandon")
    elseif o.status == "ready" then
        if origin == "plain" then Add("keep_seed"); Add("share_seed"); Add("keep_food")
        elseif origin == "artisan" then Add("take_cash"); Add("take_discount")
        elseif origin == "merchant" then Add("settle"); Add("renew", "adult")
        elseif origin == "gentry" then Add("study_referral", "study_target"); Add("work_referral", "work_target") end
        Add("abandon")
    end
    return result
end

local function BusyReason(run, memberId, ownProjectId)
    for _, task in ipairs(run.relicTasks or {}) do
        if task.status == "active" and (task.executorId == memberId or Has(task.participantIds, memberId)) then
            return "正在办理信物事务“" .. tostring(task.actionId) .. "”，请先暂停该事务。"
        end
    end
    for id, project in pairs(run.relicExternalProjects or {}) do
        if id ~= ownProjectId and project.status == "active" and Has(project.participantIds, memberId) then
            return "正在办理“" .. tostring((project.metadata or {}).name or id) .. "”，请先暂停该事务。"
        end
    end
end

local function WorkerReason(run, o, member, checkSlot)
    if not Alive(member) then return "请选择一位在世办理人。" end
    if not State.IsAdult(member) then return "办理人须年满 " .. Data.AgeRules.adult .. " 岁。" end
    local origin, stats = o.sourceOriginId, member.stats
    if origin == "plain" and (member.jobId ~= "farm" or run.land < 1) then return "需要至少1亩田地，办理人当前安排为耕作。" end
    if origin == "artisan" and (stats.skill or 0) < 35 then return "办理人手艺须达到35。" end
    if origin == "merchant" and (stats.trade or 0) < 25 then return "续单办理人经营须达到25。" end
    if origin == "military" and ((stats.martial or 0) < 35 or member.health < 50) then return "护送需要武艺35、体魄50。" end
    if checkSlot then return BusyReason(run, member.id, o.projectId) end
end

local function AttachmentReasons(run, ids, ownProjectId, reasons)
    local seen = {}
    for _, id in ipairs(ids or {}) do
        local item = RelicState.Find(run, id)
        if seen[id] then table.insert(reasons, "同一信物不能重复挂入工程。") end
        seen[id] = true
        if not item or item.status ~= "held" or item.availability ~= "usable" or (item.relicFamilyId ~= "ruler" and item.relicFamilyId ~= "plan") then
            table.insert(reasons, "工程仅可挂入当前可用的木尺与营造图。")
        end
        for _, task in ipairs(run.relicTasks or {}) do
            if (task.status == "active" or task.status == "ready" or task.status == "paused_manual" or task.status == "paused_actor" or task.status == "paused_requirements")
                and (task.instanceId == id or task.status == "active" and Has(task.attachedInstanceIds, id)) then
                table.insert(reasons, "该信物仍有未结事务。")
            end
        end
        for projectId, project in pairs(run.relicExternalProjects or {}) do
            if projectId ~= ownProjectId and project.status == "active" and Has(project.attachedInstanceIds, id) then table.insert(reasons, "该信物正在参与其他工程。") end
        end
    end
end

local function RushChance(run, member)
    local martial = member and member.stats.martial or 35
    return math.min(0.90, math.max(0.50, 0.70 + math.floor((martial - 35) / 5) * 0.02 - (run.eraId == "unrest" and 0.10 or 0)))
end

function O.Quote(run, actionId, input)
    input = input or {}
    local o, action = O.Get(run), nil
    local q = { allowed = false, reasons = {}, cost = { money = 0, grain = 0 }, workYears = 0,
        label = labels[actionId] or "未知操作", description = "" }
    for _, value in ipairs(O.Actions(run)) do if value.id == actionId then action = value end end
    if not o or not action then q.reasons = { "当前阶段无法执行这项操作。" }; return q end
    local member, origin = Member(run, input.memberId), o.sourceOriginId
    if action.inputKind ~= "none" then
        if not Alive(member) then table.insert(q.reasons, "请选择一位在世族人。")
        elseif action.inputKind == "study" or action.inputKind == "study_target" then
            if member.age < Data.AgeRules.study then table.insert(q.reasons, "读者须年满 " .. Data.AgeRules.study .. " 岁。") end
            if action.inputKind == "study" and member.jobId ~= "study" then table.insert(q.reasons, "读者当前须安排为读书求学。") end
            local eligible, reason = State.CanUseJob(member, "study")
            if not eligible then table.insert(q.reasons, reason) end
        elseif not State.IsAdult(member) then table.insert(q.reasons, "请选择在世成年人。") end
    end
    local work = actionId == "start" or actionId == "renew" or actionId == "safe" or actionId == "rush" or actionId == "resume"
    if work then
        local reason = WorkerReason(run, o, member, true)
        if reason then table.insert(q.reasons, reason) end
        q.workYears = 1 - o.completedWorkYears
        local ids = actionId == "resume" and o.attachedRelicIds or input.attachedInstanceIds
        if origin == "artisan" then AttachmentReasons(run, ids, o.projectId, q.reasons)
        elseif #(input.attachedInstanceIds or {}) > 0 then table.insert(q.reasons, "这项机会不挂入工程信物。") end
    end
    if actionId == "start" then
        if origin == "plain" then q.cost.grain = 4; q.description = "现在付4石粮；完成1个有效耕作年后，生活结算后额外收粮8石，再选择用途。"
        elseif origin == "artisan" then q.cost.money = 8; q.description = "现在付8两工料；完成1个有效工作年，手艺+3，再选22两回款（工料8＋报酬14），或14两回款（工料8＋报酬6）与一次作坊减免16两。"
        else q.cost.money = 8; q.description = "现在付8两；完成1个有效工作年后声望+8，再选一次求学或谋生引荐。" end
    elseif actionId == "audit" then q.cost.money = 2; q.description = "支付2两对账费，即时核实旧欠12两；本次尚未到账。此后可结清或另付12两续单。"
    elseif actionId == "settle" then q.description = "即时收回旧欠12两，连同已付对账费2两，事件净得10两。"
    elseif actionId == "renew" then q.cost.money = 12; q.description = "再投入12两交易本金，完成1个有效工作年后回款30两：本金12＋旧欠12＋利润6，经营+3；含对账费总净得16两。"
    elseif actionId == "borrow" then q.cost.money = 8; q.description = "支付整理费2两、押金6两；未来3个自然年内，指定读者最多2个实际付费读书年各加学识3。第" .. tostring(run.yearIndex + 3) .. "年末前归还退押金6两；之后每完整年扣押金2两，最多6两。"
    elseif actionId == "return" then q.description = "现在归还退押金" .. tostring(o.deposit) .. "两。已得学识保留，未用阅读次数作废；本局不能再次借入。"
    elseif actionId == "assign_reader" then q.description = "免费更换读者，借期、押金和全家剩余阅读次数保持不变。"
    elseif actionId == "safe" then q.cost.money = 6; q.description = "支付盘缠6两；完成1个有效工作年后回款18两（盘缠6＋报酬12），武艺+2；事件净得12两。"
    elseif actionId == "rush" then
        q.cost.money = 8; q.successChance = RushChance(run, member)
        q.description = "支付盘缠8两。当前成功率" .. tostring(math.floor(q.successChance * 100 + 0.5)) .. "%（结算依实际年初武艺及世道）；成功回款32两（盘缠8＋报酬24）、武艺+3；失败退未用盘缠6两，净支出2两、体魄-8、武艺+1。接取时固定抽签，暂停、换人和读档保留同次抽签。"
    elseif actionId == "keep_seed" then q.cost.grain = 2; q.description = "再付2石；今后3个有田且有人实际耕作的年度，全家每年增粮2石，无自然期限。"
    elseif actionId == "share_seed" then q.cost.grain = 2; q.description = "再付2石分给邻人，声望+4。"
    elseif actionId == "keep_food" then q.description = "保留已收获的8石作为家用，本次不再改变钱粮。"
    elseif actionId == "take_cash" then q.description = "领取22两：返还工料8两＋报酬14两。本次修缮净得14两；领取后不能再选优惠。"
    elseif actionId == "take_discount" then
        q.description = "领取14两：返还工料8两＋报酬6两；今后一次成功购置作坊减免至多16两，优惠不计为公库余额。"
        if run.workshop then table.insert(q.reasons, "家中已有作坊，请选择领取22两。") end
    elseif actionId == "study_referral" then q.description = "固定引荐这位族人；从下一年至第" .. tostring(run.yearIndex + 6) .. "年，最多3个实际付费读书年各加学识2；不能换人，对象离世后剩余失效。"
    elseif actionId == "work_referral" then q.description = "固定引荐这位族人；从下一年至第" .. tostring(run.yearIndex + 4) .. "年，最多2个实际手艺、经商、教书、行医或护卫年度各加收入6两；不能换人，对象离世后剩余失效。"
    elseif actionId == "pause" then q.description = "暂停并释放办理人名额；保留同一任务、进度及抽签，已付费用不退，恢复不再收费。"
    elseif actionId == "resume" then q.description = "免费继续原任务，可更换合格办理人；已付费用、进度、工程挂入信物及抽签均保留。"
    elseif actionId == "abandon" then q.description = "本局永久放弃这次机会；已付工料和交易投入不退，未领取的报酬作废，已完成的成长和工程事实保留。" end
    if work and actionId ~= "resume" then q.description = q.description .. " 可兼顾主业；暂停保留进度，放弃不退已付费用。" end
    if run.money < q.cost.money then table.insert(q.reasons, "现银不足，需要 " .. tostring(q.cost.money) .. " 两。") end
    if run.grain < q.cost.grain then table.insert(q.reasons, "存粮不足，需要 " .. tostring(q.cost.grain) .. " 石。") end
    q.allowed = #q.reasons == 0
    return q
end

local function Release(run, o, status)
    local project = Project(run, o)
    if project and project.status == "active" then project.status = status end
end

function O.Execute(run, actionId, input)
    input = input or {}
    local q = O.Quote(run, actionId, input)
    if not q.allowed then return false, table.concat(q.reasons, "；") end
    local o = assert(O.Get(run))
    local origin, wasAvailable = o.sourceOriginId, o.status == "available"
    local work = actionId == "start" or actionId == "renew" or actionId == "safe" or actionId == "rush"
    if work then
        local id = o.instanceId .. ":work"
        local ok, message = RelicSystem.RegisterExternalProject(run, id, { input.memberId }, input.attachedInstanceIds or {}, { opportunityId = o.id, name = OriginState.Definitions[origin].name })
        if not ok then return false, message end
        o.projectId = id; o.actorId = input.memberId; o.attachedRelicIds = State.Copy(input.attachedInstanceIds or {})
        o.status = "active"; o.stage = actionId; o.startedAfterYear = run.yearIndex
    end
    if wasAvailable then o.starts = 1; o.claims.open = true; o.stage = actionId end
    if actionId ~= "pause" and actionId ~= "resume" and actionId ~= "assign_reader" then o.claims[actionId] = true end
    if q.cost.money > 0 then
        if actionId == "borrow" then
            o.readerId = input.memberId
            Flow(run, "event_fee", -2, 0, "旧卷整理费", "borrow.fee")
            Flow(run, "deposit_out", -6, 0, "旧卷押金暂存", "borrow.deposit")
            o.paid.feeSilver = o.paid.feeSilver + 2; o.paid.depositSilver = 6
        else
            local capital = actionId == "renew"
            Flow(run, capital and "trade_capital_out" or "event_fee", -q.cost.money, 0, q.label .. "支出", actionId .. ".cost")
            local key = capital and "capitalSilver" or "feeSilver"
            o.paid[key] = o.paid[key] + q.cost.money
        end
    end
    if q.cost.grain > 0 then Flow(run, "event_grain_out", 0, -q.cost.grain, q.label .. "支粮", actionId .. ".cost"); o.paid.grain = o.paid.grain + q.cost.grain end
    if actionId == "pause" then o.status = "paused"; o.pauseReason = "主动暂停，无需重付。"; Release(run, o, "paused")
    elseif actionId == "resume" then
        local project = assert(Project(run, o), "原任务的工程记录缺失。")
        project.participantIds = { input.memberId }; project.status = "active"
        o.actorId = input.memberId; o.status = "active"; o.pauseReason = nil
    elseif actionId == "abandon" then
        o.status = "abandoned"; Release(run, o, "cancelled")
        if origin == "merchant" and o.stage == "renew" then o.relationshipStatus = "business_unfinished" end
    elseif actionId == "audit" then o.actorId = input.memberId; o.status = "ready"; o.stage = "account_verified"; o.relationshipStatus = "account_verified"
    elseif actionId == "settle" then Flow(run, "old_debt_recovery", 12, 0, "旧欠回收", "settle.debt"); o.status = "settled"; o.relationshipStatus = "account_settled"
    elseif actionId == "borrow" then
        o.status = "active"; o.stage = "loan"; o.borrowedAfterYear = run.yearIndex; o.dueAfterYear = run.yearIndex + 3
        o.deposit = 6; o.latePenalty = 0; o.depositRefunded = 0
        Benefit(run, "scroll", 3, 2, input.memberId, 3)
    elseif actionId == "return" then
        Flow(run, "deposit_return", o.deposit, 0, "归还旧卷退押金", "return.deposit")
        o.depositRefunded = o.deposit; o.deposit = 0; o.status = "returned"; o.benefits.scroll.active = false; o.benefits.scroll.spentReason = "已归还旧卷"
    elseif actionId == "assign_reader" then o.readerId = input.memberId; o.benefits.scroll.memberId = input.memberId
    elseif actionId == "safe" or actionId == "rush" then o.route = actionId; if actionId == "rush" then o.riskDraw = State.Random(run) end
    elseif actionId == "keep_seed" then Benefit(run, "seed", 2, 3); o.status = "settled"
    elseif actionId == "share_seed" then run.reputation = run.reputation + 4; o.status = "settled"
    elseif actionId == "keep_food" then o.status = "settled"
    elseif actionId == "take_cash" or actionId == "take_discount" then
        Flow(run, "trade_capital_return", 8, 0, "修缮工料返还", "repair.materials")
        Flow(run, "event_wage", actionId == "take_cash" and 14 or 6, 0, "修缮报酬", "repair.wage")
        if actionId == "take_discount" then Benefit(run, "workshop_discount", 16, 1) end
        o.status = "settled"
    elseif actionId == "study_referral" then Benefit(run, "study_referral", 2, 3, input.memberId, 6); o.status = "settled"; o.relationshipStatus = "referred_to_study"
    elseif actionId == "work_referral" then Benefit(run, "work_referral", 6, 2, input.memberId, 4); o.status = "settled"; o.relationshipStatus = "referred_to_work" end
    Fact(run, o.relationshipStatus or actionId, q.label .. "。" .. q.description, input.memberId or o.actorId or o.readerId)
    return true, q.label .. "，已记入家史。"
end

local function Growth(member, stat, amount)
    local before = member.stats[stat] or 0
    member.stats[stat] = math.min(100, before + amount)
    return member.stats[stat] - before
end

local function FinishWork(run, yearStart, ledger, o)
    local actor = Member(yearStart, o.actorId)
    local reason = WorkerReason(yearStart, o, actor, false)
    local row
    for _, entry in ipairs(ledger.members or {}) do if entry.memberId == o.actorId then row = entry end end
    local project = assert(Project(run, o), "背景任务缺少工程记录。")
    if project.status == "cancelled" then o.status = "abandoned"; o.pauseReason = "工程所用信物已移出。"; return end
    if reason or not row or not row.executed or not Alive(Member(run, o.actorId)) then
        o.status = "paused_actor"; o.pauseReason = reason or (row and row.reason) or "办理人本年度未实际完成安排。"
        Release(run, o, "paused_actor"); return
    end
    local current = assert(Member(run, o.actorId))
    local origin, success = o.sourceOriginId, true
    o.completedWorkYears = 1; o.completionYear = run.yearIndex
    o.workFacts = State.Copy(project.workFacts)
    o.status = "ready"
    if origin == "plain" then Flow(run, "event_grain_in", 0, 8, "试种收获", "work.harvest")
    elseif origin == "artisan" then o.growth = Growth(current, "skill", 3)
    elseif origin == "merchant" then
        Flow(run, "trade_capital_return", 12, 0, "续单本金返还", "renew.capital")
        Flow(run, "old_debt_recovery", 12, 0, "续单带回旧欠", "renew.debt")
        Flow(run, "trade_profit", 6, 0, "续单利润", "renew.profit")
        o.growth = Growth(current, "trade", 3); o.status = "settled"; o.relationshipStatus = "business_reconnected"
    elseif origin == "military" then
        o.successChance = RushChance(yearStart, actor)
        success = o.route == "safe" or o.riskDraw < o.successChance
        local returned = o.route == "safe" and 6 or (success and 8 or 6)
        Flow(run, "trade_capital_return", returned, 0, success and "护送盘缠返还" or "急件退回未用盘缠", "escort.expenses")
        if success then Flow(run, "event_wage", o.route == "safe" and 12 or 24, 0, "护送报酬", "escort.wage")
        else current.health = math.max(0, current.health - 8) end
        o.growth = Growth(current, "martial", success and (o.route == "safe" and 2 or 3) or 1)
        o.status = success and "settled" or "settled_failure"
    elseif origin == "gentry" then run.reputation = run.reputation + 8; o.relationshipStatus = "guest_received" end
    local ok, message = RelicSystem.AdvanceExternalProject(run, o.projectId, run.yearIndex, { o.actorId }, o.attachedRelicIds, success and "success" or "failed")
    assert(ok, message)
    o.claims.work = true
    Fact(run, o.relationshipStatus or (success and "work_completed" or "escort_failed"), OriginState.Definitions[origin].name .. (success and "完成了约定的工作年度。" or "急件护送未成功，已按约退回未用盘缠。"), o.actorId)
end

function O.Tick(run, yearStart, ledger)
    local o = O.Get(run)
    if not o or o.lastProcessedYear == run.yearIndex or run.ending then return end
    local used = {}
    local function Consume(source, memberId)
        if used[source.benefitId] then return end
        local benefit = assert(o.benefits[source.benefitId], "年度权益来源缺失。")
        local start = assert(yearStart.originOpportunity.benefits[source.benefitId], "年初权益来源缺失。")
        assert(start.active and start.remainingUses > 0, "年度权益次数无效。")
        benefit.remainingUses = benefit.remainingUses - 1; benefit.lastAppliedYear = run.yearIndex
        used[source.benefitId] = true
        if benefit.remainingUses == 0 then benefit.active = false; benefit.spentReason = "次数已用完" end
        Fact(run, "benefit_applied", "背景机会权益生效：" .. tostring(source.learn or 0) .. "学识、" .. tostring(source.money or 0) .. "两、" .. tostring(source.grain or 0) .. "石。", memberId)
    end
    for _, row in ipairs(ledger.members or {}) do for _, source in ipairs(row.originSources or {}) do Consume(source, row.memberId) end end
    for _, source in ipairs(ledger.originGrainSources or {}) do Consume(source) end
    if Working(o) then FinishWork(run, yearStart, ledger, o) end
    for _, benefit in pairs(o.benefits) do
        if benefit.active and benefit.expiresAfterYear and run.yearIndex >= benefit.expiresAfterYear then
            benefit.active = false; benefit.spentReason = "自然期限已结束"
        end
    end
    if o.sourceOriginId == "scholar" and o.status == "active" then
        local penalty = math.min(6, math.max(0, run.yearIndex - o.dueAfterYear) * 2)
        local added = penalty - o.latePenalty
        if added > 0 then
            o.deposit = o.deposit - added; o.latePenalty = penalty; o.lastPenaltyYear = run.yearIndex
            local entry = Flow(run, "deposit_forfeited", 0, 0, "旧卷逾期扣押金" .. tostring(added) .. "两", "loan.penalty." .. tostring(run.yearIndex))
            entry.depositLoss = added
            Fact(run, "deposit_forfeited", entry.description)
        end
        if o.deposit == 0 then o.status = "reclaimed"; o.benefits.scroll.active = false; Fact(run, "reclaimed", "旧卷到期收回，押金已扣完。") end
    end
    ledger.originTransactions = {}
    for _, entry in ipairs(run.originTransactions) do if entry.yearIndex == run.yearIndex then table.insert(ledger.originTransactions, State.Copy(entry)) end end
    ledger.money, ledger.grain = run.money, run.grain
    ledger.netMoney, ledger.netGrain = run.money - ledger.beforeMoney, run.grain - ledger.beforeGrain
    ledger.resourcesExhausted = run.money == 0 and run.grain == 0
    o.lastProcessedYear = run.yearIndex
end

function O.AfterDeaths(run)
    local o = O.Get(run)
    if not o then return end
    if Working(o) and not Alive(Member(run, o.actorId)) then
        o.status = "paused_actor"; o.pauseReason = "办理人离世，请选择接手人，无需重付。"; Release(run, o, "paused_actor")
    end
    if o.readerId and not Alive(Member(run, o.readerId)) then o.readerId = nil; if o.benefits.scroll then o.benefits.scroll.memberId = nil end end
    for _, benefit in pairs(o.benefits) do
        if benefit.active and benefit.memberId and not Alive(Member(run, benefit.memberId)) and benefit.kind ~= "scroll" then
            benefit.active = false; benefit.spentReason = "引荐对象已离世"
        end
    end
end

function O.AssetQuote(run, assetId, basePrice)
    local o = O.Get(run)
    local benefit = o and o.benefits.workshop_discount
    local discount = assetId == "workshop" and not run.workshop and benefit and benefit.active and benefit.remainingUses > 0 and math.min(16, basePrice) or 0
    return { price = basePrice - discount, basePrice = basePrice, discount = discount }
end

function O.RecordAssetPurchase(run, quote)
    if quote.discount <= 0 then return end
    local o = assert(O.Get(run))
    local benefit = assert(o.benefits.workshop_discount)
    assert(benefit.active and benefit.remainingUses == 1, "作坊优惠已消费。")
    benefit.remainingUses = 0; benefit.active = false; benefit.spentReason = "已用于购置作坊"
    local entry = Flow(run, "benefit_discount", 0, 0, "购置作坊实际减免" .. tostring(quote.discount) .. "两", "workshop.discount")
    entry.discount = quote.discount
    Fact(run, "workshop_discount", entry.description)
end

function O.Archive(run)
    local o = O.Get(run)
    if not o then return end
    o.archivedStatus = o.status; o.status = "archived"; o.archivedYear = run.yearIndex
    Release(run, o, "archived")
    for _, benefit in pairs(o.benefits) do benefit.active = false; benefit.spentReason = "本局已落笔" end
end

local statusNames = { available = "留待以后", active = "办理中", paused = "已暂停", paused_actor = "等待接手人", ready = "已完成，待选结果",
    settled = "已完成", abandoned = "已放弃", settled_failure = "护送未成功", returned = "已归还", reclaimed = "已收回", archived = "已归档" }
function O.Summary(run)
    local o = O.Get(run)
    if not o then return nil end
    local definition = OriginState.Definitions[o.sourceOriginId]
    local member = Member(run, o.readerId or o.actorId)
    local detail = member and ((o.sourceOriginId == "scholar" and "读者：" or "办理人：") .. member.name) or "尚未指定办理人"
    if o.status == "available" then
        local offers = {
            plain = "支付4石 · 1个耕作年 · 额外收粮8石",
            artisan = "支付8两 · 1个工作年 · 领22两或14两＋作坊优惠",
            merchant = "先付2两对账 · 即时核实旧欠12两",
            scholar = "支付8两（含押金6）· 借期3年 · 最多2次学识+3",
            military = "稳路付6领18；急件付8 · 成功领32，失败退6",
            gentry = "支付8两 · 1个工作年 · 声望+8，再选引荐",
        }
        detail = offers[o.sourceOriginId]
    end
    if o.sourceOriginId == "scholar" and o.deposit ~= nil then
        detail = detail .. " · 押金余" .. tostring(o.deposit) .. "两 · 本局第" .. tostring(o.dueAfterYear) .. "年末前归还"
    elseif o.starts > 0 then detail = detail .. " · 工作年 " .. tostring(o.completedWorkYears) .. "/1" end
    if o.pauseReason then detail = detail .. "\n" .. o.pauseReason end
    local benefits = {}
    local names = { seed = "留种增产", workshop_discount = "作坊减免", scroll = "旧卷阅读", study_referral = "求学引荐", work_referral = "谋生引荐" }
    for _, key in ipairs({ "seed", "workshop_discount", "scroll", "study_referral", "work_referral" }) do
        local benefit = o.benefits[key]
        if benefit then
            local target = benefit.memberId and Member(run, benefit.memberId)
            table.insert(benefits, names[key] .. (target and " · " .. target.name or "") .. "：余" .. tostring(benefit.remainingUses) .. "次"
                .. (benefit.expiresAfterYear and "，第" .. tostring(benefit.expiresAfterYear) .. "年末到期" or "")
                .. (benefit.active and "" or " · " .. tostring(benefit.spentReason)))
        end
    end
    return { title = definition.name, originName = Data.Origin(o.sourceOriginId).name,
        statusText = statusNames[o.status], detail = detail, benefitsText = table.concat(benefits, "\n") }
end

return O
