local Data = require "Jiaye.Data"
local Definitions = require "Jiaye.RelicDefinitions"

local RelicState = {}

local function List(value)
    return type(value) == "table" and value or {}
end

local function Map(value)
    return type(value) == "table" and value or {}
end

local function IsAlive(member)
    return type(member) == "table" and member.alive ~= false
end

local function Age(member)
    return type(member) == "table" and type(member.age) == "number" and member.age or -1
end

local function IsAdult(member)
    return IsAlive(member) and Age(member) >= Data.AgeRules.adult
end

local function Stat(member, id)
    local stats = Map(member and member.stats)
    if type(stats[id]) == "number" then return stats[id] end
    local experience = member and Data.Experience(member.experienceId)
    local values = experience and experience.values or nil
    return type(values) == "table" and type(values[id]) == "number" and values[id] or 0
end

local function Job(member)
    local jobId = member and member.jobId
    return jobId and Data.Jobs[jobId] or nil
end

local function HasJobRequirements(member)
    local job = Job(member)
    if not job or Age(member) < (job.min or 0) then return false end
    if job.req and Stat(member, job.req[1]) < job.req[2] then return false end
    return true
end

local function FamilyIdForForm(formId)
    local form = Definitions.Form(formId)
    return form and form.familyId or nil
end

local function FormFromValues(familyId, tier, branch)
    if not familyId or not tier then return nil end
    if branch then return Definitions.Form(familyId .. "." .. tostring(tier) .. "." .. branch) end
    return Definitions.Form(familyId .. "." .. tostring(tier))
end

local function LegacyFormId(id)
    if id == "book" then return "genealogy.1" end
    if id == "newbook" then return "genealogy.2" end
    if id == "ruler" then return "ruler.1" end
    if id == "letter" then return "letter.1" end
    if id == "plan" then return "plan.1" end
    if id == "jade" then return "jade.1" end
    if id == "notes" then return "notes.1" end
    return id
end

function RelicState.IsNew(run)
    return type(run) == "table" and run.relicRulesVersion == Definitions.VERSION
end

function RelicState.EnsureProfile(profile)
    profile = type(profile) == "table" and profile or {}
    local forms = Map(profile.unlockedRelicForms)
    local old = Map(profile.unlockedRelicIds)
    if old.book or old["genealogy.1"] then forms["genealogy.1"] = true end
    if old.newbook or old["genealogy.2"] then forms["genealogy.2"] = true end
    if old.ruler or old["ruler.1"] then forms["ruler.1"] = true end
    if old.letter or old["letter.1"] then forms["letter.1"] = true end
    if old.plan or old["plan.1"] then forms["plan.1"] = true end
    if old.jade or old["jade.1"] then forms["jade.1"] = true end
    if old.notes or old["notes.1"] then forms["notes.1"] = true end
    if next(forms) == nil then
        forms["genealogy.1"] = true
        forms["ruler.1"] = true
        forms["letter.1"] = true
    end
    if profile.schemaVersion == nil then profile.schemaVersion = 1 end
    profile.unlockedRelicForms = forms
    return profile
end

function RelicState.EnsureRun(run)
    if type(run) ~= "table" or run.relicRulesVersion ~= Definitions.VERSION then return run, false end
    if type(run.relicTasks) ~= "table" then run.relicTasks = {} end
    if type(run.relicClaims) ~= "table" then run.relicClaims = {} end
    if type(run.relicCooldowns) ~= "table" then run.relicCooldowns = {} end
    if type(run.primaryRelics) ~= "table" then run.primaryRelics = {} end
    if type(run.relicUseFacts) ~= "table" then run.relicUseFacts = {} end
    if type(run.relicProjectFacts) ~= "table" then run.relicProjectFacts = {} end
    return run, true
end

function RelicState.Find(run, id)
    if type(run) ~= "table" then return nil end
    for _, instance in ipairs(List(run.relicInstances)) do
        if type(instance) == "table" and instance.instanceId == id then return instance end
    end
    return nil
end

function RelicState.Form(instance)
    if type(instance) ~= "table" then return nil end
    local direct = instance.formId and Definitions.Form(instance.formId)
    if direct then return direct end
    local legacyId = instance.definitionId or instance.legacyId
    local mapped = legacyId and Definitions.LegacyForm(LegacyFormId(legacyId))
    if mapped then return mapped end
    return FormFromValues(instance.relicFamilyId, instance.tier, instance.branch)
end

function RelicState.Primary(run, familyId)
    if type(run) ~= "table" then return nil end
    local primaryId = Map(run.primaryRelics)[familyId]
    if primaryId then return RelicState.Find(run, primaryId) end
    return nil
end

local function FormForInstanceOrId(instance)
    if type(instance) == "string" then return Definitions.Form(instance) end
    return RelicState.Form(instance)
end

function RelicState.EligibleUser(run, instance, member)
    if not IsAlive(member) then return false, "使用人必须在世。" end
    local form = FormForInstanceOrId(instance)
    if not form then return false, "信物形态不存在。" end
    if form.familyId == "letter" or form.familyId == "jade" or form.familyId == "genealogy" then
        if not IsAdult(member) then return false, "使用人必须是成年族人。" end
    end
    if form.familyId == "genealogy" and Stat(member, "learn") < 25 then return false, "修谱人需要学识达到25。" end
    if form.familyId == "jade" and Stat(member, "learn") < 25 and Stat(member, "trade") < 25 then return false, "联络人需要学识或经营达到25。" end
    if form.familyId == "ruler" then
        if member.jobId ~= "apprentice" and member.jobId ~= "craft" then return false, "木尺使用人必须实际学艺或手艺谋生。" end
        if not HasJobRequirements(member) then return false, "木尺使用人尚未满足当前安排的年龄或能力要求。" end
    elseif form.familyId == "plan" then
        if member.jobId ~= "craft" or not HasJobRequirements(member) then return false, "营造图使用人必须是合格的手艺谋生者。" end
    elseif form.familyId == "notes" then
        if member.jobId ~= "medical" and member.jobId ~= "doctor" then return false, "医案使用人必须实际学医或行医。" end
        if not HasJobRequirements(member) then return false, "医案使用人尚未满足当前安排的年龄或能力要求。" end
    end
    return true, ""
end

function RelicState.EffectsFor(run, member)
    local effects = { skill = 0, medicine = 0, money = 0, relicSources = {} }
    if type(run) ~= "table" or type(member) ~= "table" then return effects end
    for _, family in ipairs(Definitions.Families) do
        local instance = RelicState.Primary(run, family.id)
        if instance and instance.status == "held" and (instance.availability or "usable") == "usable" and instance.userId == member.id then
            local form = RelicState.Form(instance)
            local eligible = form and RelicState.EligibleUser(run, instance, member)
            if form and eligible then
                local annual = form.annual or {}
                effects.skill = effects.skill + (annual.skill or 0)
                effects.medicine = effects.medicine + (annual.medicine or 0)
                effects.money = effects.money + (annual.money or 0)
                effects.relicSources[family.id] = { instanceId = instance.instanceId, formId = form.id, skill = annual.skill or 0, medicine = annual.medicine or 0, money = annual.money or 0 }
            end
        end
    end
    return effects
end

local function UserScore(form, member)
    if form.familyId == "ruler" or form.familyId == "plan" then return Stat(member, "skill") end
    if form.familyId == "notes" then return Stat(member, "medicine") end
    if form.familyId == "jade" then return math.max(Stat(member, "learn"), Stat(member, "trade")) end
    if form.familyId == "genealogy" then return Stat(member, "learn") end
    return 0
end

function RelicState.SuggestUser(members, formId)
    local form = Definitions.Form(formId)
    if not form then return nil end
    local candidates = {}
    for _, member in ipairs(List(members)) do
        local ok = RelicState.EligibleUser({}, form.id, member)
        if ok then table.insert(candidates, member) end
    end
    table.sort(candidates, function(left, right)
        local leftScore, rightScore = UserScore(form, left), UserScore(form, right)
        if leftScore ~= rightScore then return leftScore > rightScore end
        return tostring(left.id) < tostring(right.id)
    end)
    return candidates[1] and candidates[1].id or nil
end

local function NextInstanceId(run, formId)
    local count = #List(run.relicInstances) + 1
    local candidate = "relic-v12-" .. tostring(count) .. "-" .. formId
    while RelicState.Find(run, candidate) do
        count = count + 1
        candidate = "relic-v12-" .. tostring(count) .. "-" .. formId
    end
    return candidate
end

local function MarkFirstClaim(run, form, instanceId, source)
    local claims = run.relicClaims
    local key = form.familyId .. ".first_acquired"
    if claims[key] == nil then claims[key] = { consumed = true, source = source, instanceId = instanceId, formId = form.id } end
end

function RelicState.CreateInstance(run, formId, source, custodianId, userId)
    local form = Definitions.Form(formId)
    if type(run) ~= "table" or not form then return nil, "信物形态不存在。" end
    if run.relicRulesVersion ~= Definitions.VERSION then return nil, "当前家谱未启用信物规则1.2。" end
    run.relicInstances = List(run.relicInstances)
    run.relicClaims = Map(run.relicClaims)
    local instance = {
        instanceId = NextInstanceId(run, form.id),
        rulesVersion = Definitions.VERSION,
        relicFamilyId = form.familyId,
        tier = form.tier,
        branch = form.branch,
        formId = form.id,
        definitionId = form.legacyId or form.id,
        status = "held",
        availability = "usable",
        userId = userId,
        custodianId = custodianId,
        taskId = nil,
        source = source,
    }
    table.insert(run.relicInstances, instance)
    MarkFirstClaim(run, form, instance.instanceId, source)
    return instance
end

local function DraftFormId(value)
    if type(value) ~= "string" then return nil end
    if Definitions.Form(value) then return value end
    local mapped = LegacyFormId(value)
    return Definitions.Form(mapped) and mapped or nil
end

function RelicState.InitNewRun(run, draft, profile)
    if type(run) ~= "table" or type(draft) ~= "table" then return run, profile end
    run.relicRulesVersion = Definitions.VERSION
    RelicState.EnsureRun(run)
    profile = RelicState.EnsureProfile(profile)
    local selected = List(draft.selectedRelicFormIds)
    local users = Map(draft.relicUsers)
    local custodians = Map(draft.relicCustodians)
    local selectedFamilies = {}
    for _, rawFormId in ipairs(selected) do
        local formId = DraftFormId(rawFormId)
        local form = formId and Definitions.Form(formId)
        if form and not selectedFamilies[form.familyId] then
            selectedFamilies[form.familyId] = true
            local userId = users[form.id]
            local custodianId = custodians[form.id] or custodians[form.legacyId] or run.leaderId
            local instance = RelicState.CreateInstance(run, form.id, "opening", custodianId, userId)
            run.primaryRelics[form.familyId] = instance.instanceId
            profile.unlockedRelicForms[form.id] = true
        end
    end
    return run, profile
end

return RelicState
