local OriginState = {}

OriginState.VERSION = "origin-opportunities-1.0"
OriginState.MAX_STARTS = 1
OriginState.REPEATABLE = false
OriginState.Definitions = {
    plain = { id = "origin.seed_exchange", alias = "plain_harvest", name = "河埠换种" },
    artisan = { id = "origin.workshop_repair", alias = "artisan_repair", name = "旧坊修缮" },
    merchant = { id = "origin.old_accounts", alias = "merchant_credit", name = "旧账重开" },
    scholar = { id = "origin.scroll_loan", alias = "scholar_archive", name = "旧卷借阅" },
    military = { id = "origin.escort", alias = "military_escort", name = "旧营护送" },
    gentry = { id = "origin.old_guest", alias = "gentry_reputation", name = "旧客重访" },
}

function OriginState.Init(run, draft)
    if draft.originRulesVersion == nil then return end
    assert(draft.originRulesVersion == OriginState.VERSION, "背景机会规则版本未知。")
    local definition = assert(OriginState.Definitions[run.originId], "背景机会来历未知。")
    run.originRulesVersion = OriginState.VERSION
    run.originOpportunity = {
        id = definition.id, instanceId = run.runId .. ":" .. definition.id,
        sourceOriginId = run.originId, rulesVersion = OriginState.VERSION,
        status = "available", starts = 0, completedWorkYears = 0, requiredWorkYears = 1,
        claims = {}, benefits = {}, paid = { feeSilver = 0, capitalSilver = 0, grain = 0, depositSilver = 0 },
        attachedRelicIds = {}, workFacts = {},
    }
    run.originTransactions = {}
end

local function Integer(value)
    return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end

local states = { available = true, active = true, paused = true, paused_actor = true, ready = true,
    settled = true, abandoned = true, settled_failure = true, returned = true, reclaimed = true, archived = true }
local benefitRules = {
    seed = { origin = "plain", uses = 3, amount = 2 },
    workshop_discount = { origin = "artisan", uses = 1, amount = 16 },
    scroll = { origin = "scholar", uses = 2, amount = 3, window = 3 },
    study_referral = { origin = "gentry", uses = 3, amount = 2, window = 6 },
    work_referral = { origin = "gentry", uses = 2, amount = 6, window = 4 },
}

function OriginState.Validate(run, memberIds)
    if run.originRulesVersion == nil then
        if run.originOpportunity ~= nil or run.originTransactions ~= nil then return false, "背景机会记录缺少规则版本。" end
        return true
    end
    local o = run.originOpportunity
    local definition = OriginState.Definitions[run.originId]
    if run.originRulesVersion ~= OriginState.VERSION or run.relicRulesVersion ~= "1.2" or type(o) ~= "table"
        or not definition or o.id ~= definition.id or o.sourceOriginId ~= run.originId
        or o.instanceId ~= run.runId .. ":" .. definition.id or o.rulesVersion ~= OriginState.VERSION
        or not states[o.status] or not Integer(o.starts) or o.starts > 1
        or not Integer(o.completedWorkYears) or o.completedWorkYears > 1 or o.requiredWorkYears ~= 1
        or type(o.claims) ~= "table" or type(o.benefits) ~= "table" or type(o.paid) ~= "table"
        or type(o.attachedRelicIds) ~= "table" or type(o.workFacts) ~= "table" or type(run.originTransactions) ~= "table" then
        return false, "背景机会结构或版本无效。"
    end
    if (o.status == "available" and o.starts ~= 0) or (o.status ~= "available" and o.status ~= "archived" and o.starts ~= 1) then
        return false, "背景机会的一次性资格记录无效。"
    end
    for _, key in ipairs({ "actorId", "readerId" }) do
        if o[key] ~= nil and not memberIds[o[key]] then return false, "背景机会人物引用无效。" end
    end
    for _, key in ipairs({ "feeSilver", "capitalSilver", "grain", "depositSilver" }) do
        if not Integer(o.paid[key]) then return false, "背景机会支付记录无效。" end
    end
    if o.starts == 1 and not o.claims.open then return false, "背景机会缺少开启凭据。" end
    if run.openingSnapshot.originRulesVersion ~= OriginState.VERSION then return false, "机会规则与开局快照不一致。" end
    for _, key in ipairs({ "startedAfterYear", "completionYear", "lastProcessedYear", "archivedYear", "lastPenaltyYear" }) do
        if o[key] ~= nil and (not Integer(o[key]) or o[key] > run.yearIndex) then return false, "机会年度记录无效。" end
    end
    if o.projectId ~= nil then
        local project = (run.relicExternalProjects or {})[o.projectId]
        if type(project) ~= "table" or project.id ~= o.projectId or type(project.workFacts) ~= "table"
            or type(project.participantIds) ~= "table" or type(project.attachedInstanceIds) ~= "table" then
            return false, "背景机会工程引用无效。"
        end
        for _, memberId in ipairs(project.participantIds) do if not memberIds[memberId] then return false, "背景工程参与人无效。" end end
        if o.status == "active" and project.status ~= "active" and project.status ~= "cancelled" then return false, "背景工程进度状态不一致。" end
    elseif o.sourceOriginId ~= "scholar" and (o.status == "active" or o.status == "paused" or o.status == "paused_actor") then
        return false, "背景机会缺少已接受的工程。"
    end
    if o.riskDraw ~= nil and (run.originId ~= "military" or o.route ~= "rush" or type(o.riskDraw) ~= "number" or o.riskDraw <= 0 or o.riskDraw >= 1) then
        return false, "护送风险记录无效。"
    end
    if o.route == "rush" and o.riskDraw == nil then return false, "急件缺少固定抽签记录。" end
    if o.deposit ~= nil then
        if run.originId ~= "scholar" or not Integer(o.deposit) or o.deposit > 6 or not Integer(o.latePenalty)
            or o.latePenalty > 6 or not Integer(o.depositRefunded) or o.deposit + o.latePenalty + o.depositRefunded ~= 6
            or not Integer(o.borrowedAfterYear) or o.dueAfterYear ~= o.borrowedAfterYear + 3 then
            return false, "旧卷押金或借期记录无效。"
        end
    end
    for id, benefit in pairs(o.benefits) do
        if type(benefit) ~= "table" then return false, "机会权益结构无效。" end
        local rule = benefitRules[benefit.kind]
        if not rule or id ~= benefit.kind or rule.origin ~= run.originId or benefit.amount ~= rule.amount
            or not Integer(benefit.remainingUses) or benefit.remainingUses > rule.uses
            or not Integer(benefit.firstEligibleYear) or type(benefit.active) ~= "boolean"
            or (benefit.memberId ~= nil and not memberIds[benefit.memberId])
            or (rule.window and benefit.expiresAfterYear ~= benefit.firstEligibleYear + rule.window - 1)
            or (not rule.window and benefit.expiresAfterYear ~= nil) then
            return false, "机会权益的对象、次数或期限无效。"
        end
    end
    if o.benefits.study_referral and o.benefits.work_referral then return false, "引荐互斥分支记录无效。" end
    local categories = { event_fee = true, trade_capital_out = true, trade_capital_return = true, old_debt_recovery = true,
        event_wage = true, trade_profit = true, deposit_out = true, deposit_return = true, deposit_forfeited = true,
        benefit_discount = true, event_grain_out = true, event_grain_in = true }
    local claims = {}
    for _, entry in ipairs(run.originTransactions) do
        if type(entry) ~= "table" or not categories[entry.category] or entry.instanceId ~= o.instanceId or entry.opportunityId ~= o.id
            or type(entry.claimKey) ~= "string" or claims[entry.claimKey] or not Integer(entry.yearIndex) or entry.yearIndex > run.yearIndex
            or type(entry.money) ~= "number" or not Integer(math.abs(entry.money))
            or type(entry.grain) ~= "number" or not Integer(math.abs(entry.grain)) then return false, "背景机会收支凭据无效。" end
        claims[entry.claimKey] = true
    end
    return true
end

return OriginState
