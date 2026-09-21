local OriginEffects = {}

OriginEffects.RULES_VERSION = "origin-opportunities-1.0"

local WORK_JOBS = {
    craft = true,
    trade = true,
    teach = true,
    doctor = true,
    guard = true,
}

local function EmptyMemberEffects()
    return { learn = 0, money = 0, sources = {} }
end

local function EmptyGrainEffects()
    return { grain = 0, sources = {} }
end

local function BenefitIds(run)
    local benefits = run and run.originOpportunity and run.originOpportunity.benefits
    local ids = {}
    if type(benefits) ~= "table" then return ids end
    for benefitId in pairs(benefits) do table.insert(ids, benefitId) end
    table.sort(ids, function(left, right) return tostring(left) < tostring(right) end)
    return ids
end

local function IsEligible(run, benefit, year)
    if type(run) ~= "table" or run.originRulesVersion ~= OriginEffects.RULES_VERSION then return false end
    if type(benefit) ~= "table" or benefit.active ~= true then return false end
    if type(benefit.remainingUses) ~= "number" or benefit.remainingUses <= 0 then return false end
    if type(year) ~= "number" then return false end
    if benefit.firstEligibleYear ~= nil and year < benefit.firstEligibleYear then return false end
    if benefit.expiresAfterYear ~= nil and year > benefit.expiresAfterYear then return false end
    return type(benefit.amount) == "number" and benefit.amount > 0
end

function OriginEffects.ForMember(run, member, year)
    local result = EmptyMemberEffects()
    if type(member) ~= "table" or member.alive == false then return result end
    if type(run) ~= "table" or run.originRulesVersion ~= OriginEffects.RULES_VERSION then return result end

    for _, benefitId in ipairs(BenefitIds(run)) do
        local benefit = run.originOpportunity.benefits[benefitId]
        if benefit.memberId ~= nil and benefit.memberId == member.id and IsEligible(run, benefit, year) then
            local learn, money = 0, 0
            if benefit.kind == "scroll" or benefit.kind == "study_referral" then
                if member.jobId == "study" then learn = benefit.amount end
            elseif benefit.kind == "work_referral" and WORK_JOBS[member.jobId] then
                money = benefit.amount
            end
            if learn > 0 or money > 0 then
                result.learn = result.learn + learn
                result.money = result.money + money
                table.insert(result.sources, { benefitId = benefitId, kind = benefit.kind, learn = learn, money = money })
            end
        end
    end
    return result
end

function OriginEffects.HouseholdGrain(run, actualRows, year)
    local result = EmptyGrainEffects()
    if type(run) ~= "table" or run.originRulesVersion ~= OriginEffects.RULES_VERSION then return result end
    if type(run.land) ~= "number" or run.land < 1 or type(actualRows) ~= "table" then return result end

    local hasActualFarm = false
    for _, row in ipairs(actualRows) do
        if type(row) == "table" and row.executed == true and row.jobId == "farm" then
            hasActualFarm = true
            break
        end
    end
    if not hasActualFarm then return result end

    for _, benefitId in ipairs(BenefitIds(run)) do
        local benefit = run.originOpportunity.benefits[benefitId]
        if benefit.kind == "seed" and benefit.memberId == nil and IsEligible(run, benefit, year) then
            result.grain = result.grain + benefit.amount
            table.insert(result.sources, { benefitId = benefitId, kind = benefit.kind, grain = benefit.amount })
        end
    end
    return result
end

return OriginEffects
