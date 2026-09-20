local Definitions = {}

Definitions.VERSION = "1.2"

Definitions.Families = {
    { id = "genealogy", name = "族谱", legacyId = "book", description = "从缺页、旁支与任期中续写家史。" },
    { id = "ruler", name = "木尺", legacyId = "ruler", description = "查匠号、传手艺，也见证两代匠人的实际使用。" },
    { id = "letter", name = "家书", legacyId = "letter", description = "把前人的托付送到收信人后辈手中。" },
    { id = "plan", name = "营造图", legacyId = "plan", description = "让真实的匠作、修缮与修桥留下工程证据。" },
    { id = "jade", name = "玉佩", legacyId = "jade", description = "核对旧交，在合璧与各执之间留下分支。" },
    { id = "notes", name = "医案", legacyId = "notes", description = "以实际行医、病例和传承形成家传医术。" },
}

local function Annual(skill, medicine, money)
    return { skill = skill or 0, medicine = medicine or 0, money = money or 0 }
end

Definitions.Forms = {
    { id = "genealogy.1", familyId = "genealogy", tier = 1, branch = nil, legacyId = "book", name = "残缺旧谱", openingPoints = 6, saleSilver = 6, description = "缺页留下陌生小名与改过名的村落，可查访旁支。", annual = Annual(), storyAvailable = true, openingHistory = nil },
    { id = "genealogy.2", familyId = "genealogy", tier = 2, branch = nil, legacyId = "newbook", name = "补完的族谱", openingPoints = 9, saleSilver = 8, description = "补入核实后的缺页，合格交接时声望+3，并可邀请旁支归家。", annual = Annual(), storyAvailable = true, openingHistory = "开局前已补完缺页；本局不补发缺页查证和补入奖励。" },
    { id = "genealogy.3", familyId = "genealogy", tier = 3, branch = nil, legacyId = "newbook", name = "续修世系谱", openingPoints = 14, saleSilver = 12, description = "续修世系，合格交接时声望+5，并可编成家史。", annual = Annual(), storyAvailable = true, openingHistory = "开局前已续修世系；本局仍可积累新的整理、交接与家史事实。" },

    { id = "ruler.1", familyId = "ruler", tier = 1, branch = nil, legacyId = "ruler", name = "磨损的老木尺", openingPoints = 6, saleSilver = 6, description = "尺背留有陌生匠号，可查访旧匠与营造图线索。", annual = Annual(), storyAvailable = true, openingHistory = nil },
    { id = "ruler.2", familyId = "ruler", tier = 2, branch = nil, legacyId = "ruler", name = "校准的木尺", openingPoints = 10, saleSilver = 8, description = "指定使用者实际学艺或手艺谋生时，手艺+1/年。", annual = Annual(1, 0, 0), storyAvailable = true, openingHistory = "开局前已完成校准；本局仍可查匠号，但不预发图样线索。" },
    { id = "ruler.3", familyId = "ruler", tier = 3, branch = nil, legacyId = "ruler", name = "传家的匠尺", openingPoints = 16, saleSilver = 12, description = "指定使用者实际学艺或手艺谋生时，手艺+2/年，并开放一次传艺。", annual = Annual(2, 0, 0), storyAvailable = true, openingHistory = "开局前已成为传家的匠尺；本局仍可查出处、传艺和积累新的工程证据。" },

    { id = "letter.1", familyId = "letter", tier = 1, branch = nil, legacyId = "letter", name = "未送达的家书", openingPoints = 4, saleSilver = 2, description = "寻访收信人后辈，继续完成前人的旧约。", annual = Annual(), storyAvailable = true, openingHistory = nil },
    { id = "letter.2", familyId = "letter", tier = 2, branch = nil, legacyId = "letter", name = "有了回音的家书", openingPoints = 5, saleSilver = 2, description = "收件信息已经核实，本局仍可兑现未了托付。", annual = Annual(), storyAvailable = true, openingHistory = "开局前已送达并收到回音；本局不补发递信成绩。" },
    { id = "letter.3", familyId = "letter", tier = 3, branch = nil, legacyId = "letter", name = "家藏往来书札", openingPoints = 2, saleSilver = 2, description = "开局前已履约，只保留一次有条件的渡难求助。", annual = Annual(), storyAvailable = true, openingHistory = "开局前已完成履约；本局不补发声望与赠玉，只保留一次困难求助。" },

    { id = "plan.1", familyId = "plan", tier = 1, branch = nil, legacyId = "plan", name = "修复的营造图", openingPoints = 10, saleSilver = 8, description = "合格使用者每年为家族带来定额收入+5两，可承接旧图活计。", annual = Annual(0, 0, 5), storyAvailable = true, openingHistory = nil },
    { id = "plan.2", familyId = "plan", tier = 2, branch = nil, legacyId = "plan", name = "增订的营造图", openingPoints = 16, saleSilver = 12, description = "合格使用者每年为家族带来定额收入+8两。", annual = Annual(0, 0, 8), storyAvailable = true, openingHistory = "开局前已增订图样；本局仍可积累使用年与外部工程证据。" },
    { id = "plan.3", familyId = "plan", tier = 3, branch = nil, legacyId = "plan", name = "传世营造图", openingPoints = 22, saleSilver = 18, description = "合格使用者每年为家族带来定额收入+11两，并开放修桥留名。", annual = Annual(0, 0, 11), storyAvailable = true, openingHistory = "开局前已成为传世图样；本局不补发过去的工程、使用年与传承证据。" },

    { id = "jade.1", familyId = "jade", tier = 1, branch = nil, legacyId = "jade", name = "来历未明的半佩", openingPoints = 8, saleSilver = 10, description = "可核实纹样、见证与旧交的来历。", annual = Annual(), storyAvailable = true, openingHistory = nil },
    { id = "jade.2", familyId = "jade", tier = 2, branch = nil, legacyId = "jade", name = "来历确证的半佩", openingPoints = 10, saleSilver = 12, description = "已有确证信息，可安排半佩相认。", annual = Annual(), storyAvailable = true, openingHistory = "开局前已核实旧交；本局不补发核实事实，仍可安排相认。" },
    { id = "jade.3.heirloom", familyId = "jade", tier = 3, branch = "heirloom", legacyId = "jade", name = "合璧传家的玉佩", openingPoints = 12, saleSilver = 16, description = "合格交接额外声望+2；本局开局不补发相认时的声望+8。", annual = Annual(), storyAvailable = true, openingHistory = "开局前已确认合璧传家；本局不补发相认时的声望，只保留后续交接权益。" },
    { id = "jade.3.alliance", familyId = "jade", tier = 3, branch = "alliance", legacyId = "jade", name = "各执半佩", openingPoints = 8, saleSilver = 12, description = "实际迁居时减免8两，两个迁居优惠至少间隔5个经营年度。", annual = Annual(), storyAvailable = true, openingHistory = "开局前已确认各执半佩；本局不补发相认声望，只保留迁居减免。" },

    { id = "notes.1", familyId = "notes", tier = 1, branch = nil, legacyId = "notes", name = "批注医案", openingPoints = 10, saleSilver = 6, description = "指定使用者实际学医或行医时，医术+2/年。", annual = Annual(0, 2, 0), storyAvailable = true, openingHistory = nil },
    { id = "notes.2", familyId = "notes", tier = 2, branch = nil, legacyId = "notes", name = "校订医案", openingPoints = 14, saleSilver = 10, description = "指定使用者实际学医或行医时，医术+3/年。", annual = Annual(0, 3, 0), storyAvailable = true, openingHistory = "开局前已校订医案；本局仍可积累病例与新的传承事实。" },
    { id = "notes.3.private", familyId = "notes", tier = 3, branch = "private", legacyId = "notes", name = "家传医案", openingPoints = 20, saleSilver = 16, description = "指定使用者实际学医或行医时，医术+4/年，保留家传路线。", annual = Annual(0, 4, 0), storyAvailable = true, openingHistory = "开局前已定为家传医案；本局不补发编订事实与一次性声望。" },
    { id = "notes.3.public", familyId = "notes", tier = 3, branch = "public", legacyId = "notes", name = "刊行医案", openingPoints = 16, saleSilver = 10, description = "指定使用者实际学医或行医时，医术+2/年，开放公开义诊。", annual = Annual(0, 2, 0), storyAvailable = true, openingHistory = "开局前已刊行医案；本局不补发刊印声望，只保留公开义诊入口。" },
}

local function Requirements(values)
    return values
end

local function Route(cost, workYears, result)
    return { cost = cost, workYears = workYears, result = result }
end

Definitions.Actions = {
    { id = "genealogy.trace_missing_page", familyId = "genealogy", name = "核对缺页", tiers = { 1 }, cost = { money = 8, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "genealogy.missing_page", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, stat = { id = "learn", min = 25 }, claimUnused = true }), routes = { fast = Route({ money = 8, grain = 0 }, 1, { ready = true, fact = "genealogy_missing_page_verified" }), slow = Route({ money = 4, grain = 0 }, 2, { ready = true, fact = "genealogy_missing_page_verified" }) }, preview = { cost = "快查8两/1年；慢查4两/2年", outcome = "核实记录、固定旁支线索，进入补入或暂存选择" } },
    { id = "genealogy.bind_verified_pages", familyId = "genealogy", name = "核实后补入", tiers = { 1 }, cost = { money = 0, grain = 0 }, workYears = 0, sealsRelic = false, claimKey = "genealogy.reconstructed", cooldownYears = 0, requirements = Requirements({ readyClaim = "genealogy.missing_page", resultFormId = "genealogy.2" }), branches = { restore = { resultFormId = "genealogy.2", fact = "book_reconstructed", cost = { money = 0, grain = 0 } }, defer = { resultFormId = "genealogy.1", fact = "genealogy_missing_page_deferred" } }, preview = { outcome = "同一实例升为补完的族谱；不创建第二本族谱" } },
    { id = "genealogy.verify_branch", familyId = "genealogy", name = "核对旁支", tiers = { 2, 3 }, cost = { money = 4, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "genealogy.branch_verified", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, stat = { id = "learn", min = 25 }, claimUnused = true }), preview = { outcome = "固定一位18—40岁、资质2/5的旁支候选；不直接加入人口" } },
    { id = "genealogy.invite_branch", familyId = "genealogy", name = "接回旁支", tiers = { 2, 3 }, cost = { money = 12, grain = 0 }, workYears = 0, sealsRelic = false, claimKey = "genealogy.branch_joined", cooldownYears = 0, requirements = Requirements({ branchCandidate = true, claimUnused = true, immediate = true }), preview = { outcome = "加入一位真实可查看、可安排的成员；本局谱系最多一人" } },
    { id = "genealogy.upgrade_3", familyId = "genealogy", name = "续修世系谱", tiers = { 2 }, cost = { money = 18, grain = 0 }, workYears = 1, sealsRelic = true, claimKey = "genealogy.continued", cooldownYears = 0, requirements = Requirements({ runYears = 10, effectiveDistinctHandovers = 2, generationUse = { generations = 2, yearsEach = 1 }, stat = { id = "learn", min = 50 }, adult = true, alive = true }), preview = { outcome = "原实例升三阶；编订年度封存，不计常规整理年和交接加成" } },
    { id = "genealogy.compile_chronicle", familyId = "genealogy", name = "编成家史", tiers = { 3 }, cost = { money = 12, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "genealogy.chronicle_compiled", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, stat = { id = "learn", min = 50 }, claimUnused = true }), preview = { outcome = "声望+12，保存当时采用的事实快照，不创造新装备" } },

    { id = "ruler.trace_mark", familyId = "ruler", name = "查匠号与校准", tiers = { 1, 2, 3 }, cost = { money = 8, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "ruler.mark_verified", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, stat = { id = "skill", min = 35 }, claimUnused = true }), routes = { fast = Route({ money = 8, grain = 0 }, 1, { fact = "ruler_mark_verified", tierOneResult = "ruler.2", clue = "plan" }), slow = Route({ money = 4, grain = 0 }, 2, { fact = "ruler_mark_verified", tierOneResult = "ruler.2", clue = "plan" }) }, preview = { outcome = "保存匠号与图样线索；一阶实际校准为二阶，高阶不重复升阶" } },
    { id = "ruler.copy_plan", familyId = "ruler", name = "誊出图样", tiers = { 1, 2, 3 }, cost = { money = 4, grain = 0 }, workYears = 0, sealsRelic = false, claimKey = "plan.first_acquired", cooldownYears = 0, requirements = Requirements({ clue = "ruler.mark_verified", claimUnused = true, immediate = true }), preview = { outcome = "取得一阶营造图；已有图样或本局已取得过图样时不重复发放" } },
    { id = "ruler.upgrade_3", familyId = "ruler", name = "重整匠尺", tiers = { 2 }, cost = { money = 16, grain = 0 }, workYears = 1, sealsRelic = true, claimKey = "ruler.inherited", cooldownYears = 0, requirements = Requirements({ useYears = 4, generations = 2, projects = 2, adult = true, alive = true, stat = { id = "skill", min = 55 } }), preview = { outcome = "原实例升三阶；封存一年，完成后手艺年度加成为+2" } },
    { id = "ruler.teach_successor", familyId = "ruler", name = "师徒传艺", tiers = { 3 }, cost = { money = 6, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "ruler.teach_successor", cooldownYears = 0, requirements = Requirements({ claimUnused = true, master = { adult = true, alive = true, job = "craft", stat = { id = "skill", min = 55 } }, apprentice = { alive = true, minAge = 12, job = "apprentice", differentFrom = "master" }, extraTaskSlots = 2 }), preview = { outcome = "学徒手艺+6，师父手艺+1；不增加职业人年，木尺不封存" } },

    { id = "letter.deliver", familyId = "letter", name = "递信寻人", tiers = { 1 }, cost = { money = 6, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "letter.delivered", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, claimUnused = true }), routes = { personal = Route({ money = 6, grain = 0 }, 1, { ready = true, fact = "letter_recipient_verified" }), entrusted = Route({ money = 3, grain = 0 }, 2, { ready = true, fact = "letter_recipient_verified" }) }, preview = { outcome = "核实收件人并进入交付或暂存；不直接给声望与玉佩" } },
    { id = "letter.confirm_delivery", familyId = "letter", name = "交付原信", tiers = { 1 }, cost = { money = 0, grain = 0 }, workYears = 0, sealsRelic = false, claimKey = "letter.delivered", cooldownYears = 0, requirements = Requirements({ readyClaim = "letter.delivered", immediate = true }), preview = { outcome = "同一实例升二阶，写入送达与回音事实" } },
    { id = "letter.fulfil_promise", familyId = "letter", name = "兑现旧托付", tiers = { 2 }, cost = { money = 8, grain = 0 }, workYears = 1, sealsRelic = true, claimKey = "letter.promise_kept", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, claimUnused = true, chooseBeforeAccept = true }), routes = { books = Route({ money = 8, grain = 0 }, 1, { reputation = 6, createFormId = "jade.1", fact = "promise_kept" }), grain = Route({ money = 0, grain = 4 }, 1, { reputation = 6, createFormId = "jade.1", fact = "promise_kept_grain" }) }, branches = { books = "购齐旧书、送还旧约", grain = "送粮助故人渡难" }, preview = { outcome = "家书升三阶、声望+6；首次同线权益可取得一阶玉佩，不重复赠送" } },
    { id = "letter.ask_aid", familyId = "letter", name = "渡难书信", tiers = { 3 }, cost = { money = 2, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "letter.aid", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, moneyBelow = 20, grainBelowAnnualNeed = true, moneyAtLeast = 2, claimUnused = true }), branches = { silver = { rewardMoney = 12, label = "援银" }, grain = { rewardGrain = 8, label = "援粮" } }, preview = { cost = "支付2两邮递费", outcome = "接受时锁定援银12两或援粮8石；本局成功一次" } },

    { id = "plan.buy_old_drawing", familyId = "plan", name = "购入旧图", minTier = 0, maxTier = 0, cost = { money = 12, grain = 0 }, workYears = 0, sealsRelic = false, claimKey = "plan.first_acquired", cooldownYears = 0, requirements = Requirements({ craftJobYears = 6, currentUser = { adult = true, alive = true, job = "craft", stat = { id = "skill", min = 55 } }, claimUnused = true, immediate = true }), preview = { outcome = "职业路线即时取得一阶营造图；与木尺誊图共享本局首次取得权益" } },
    { id = "plan.small_repair", familyId = "plan", tiers = { 1, 2, 3 }, name = "旧图上的活计", cost = { money = 8, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "plan.small_repair", cooldownYears = 3, requirements = Requirements({ adult = true, alive = true, stat = { id = "skill", min = 40 }, available = true, mountedForm = true }), preview = { cost = "现在付8两", outcome = "1年后到账18两，净报酬10两；办理人手艺+2；冷却3年" } },
    { id = "plan.upgrade_2", familyId = "plan", name = "增订图样", tiers = { 1 }, cost = { money = 12, grain = 0 }, workYears = 1, sealsRelic = true, claimKey = "plan.upgraded_2", cooldownYears = 0, requirements = Requirements({ useYears = 3, projects = 1, adult = true, alive = true, stat = { id = "skill", min = 50 } }), preview = { outcome = "原实例升二阶；封存一年，完成后定额收入为+8两/年" } },
    { id = "plan.upgrade_3", familyId = "plan", name = "传世图样", tiers = { 2 }, cost = { money = 18, grain = 0 }, workYears = 1, sealsRelic = true, claimKey = "plan.upgraded_3", cooldownYears = 0, requirements = Requirements({ useYears = 6, generations = 2, projects = 2, adult = true, alive = true, stat = { id = "skill", min = 65 } }), preview = { outcome = "原实例升三阶；封存一年，完成后定额收入为+11两/年" } },
    { id = "plan.bridge", familyId = "plan", name = "修桥留名", tiers = { 3 }, cost = { money = 24, grain = 0 }, workYears = 2, sealsRelic = false, claimKey = "plan.bridge", cooldownYears = 0, requirements = Requirements({ claimUnused = true, adult = true, alive = true, stat = { id = "skill", min = 65 }, available = true }), preview = { cost = "24两工料", outcome = "2年后到账40两，声望+10，最后办理人手艺+4，记录bridge_completed" } },

    { id = "jade.verify_origin", familyId = "jade", name = "核实半佩", tiers = { 1 }, cost = { money = 6, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "jade.origin_verified", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, anyStat = { { id = "learn", min = 25 }, { id = "trade", min = 25 } }, claimUnused = true }), preview = { outcome = "形成二阶确证半佩，不改变血缘关系" } },
    { id = "jade.meet", familyId = "jade", name = "安排相认", tiers = { 2 }, cost = { money = 12, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "jade.reunion", cooldownYears = 0, requirements = Requirements({ adult = true, alive = true, anyStat = { { id = "learn", min = 25 }, { id = "trade", min = 25 } }, claimUnused = true }), preview = { outcome = "一年后进入合璧或各执的终形选择；选择前不发终形奖励" } },
    { id = "jade.choose_final_form", familyId = "jade", name = "确认玉佩终形", tiers = { 2 }, cost = { money = 0, grain = 0 }, workYears = 0, sealsRelic = false, claimKey = "jade.final_form", cooldownYears = 0, requirements = Requirements({ readyClaim = "jade.reunion", immediate = true, chooseBeforeAccept = true }), branches = { heirloom = { resultFormId = "jade.3.heirloom", reputation = 8, fact = "jade_reunited" }, alliance = { resultFormId = "jade.3.alliance", discountSilver = 8, fact = "jade_reunited_alliance" } }, preview = { outcome = "合璧当次声望+8并开放交接加成；各执开放迁居减免8两，终形互斥" } },

    { id = "notes.accept_old_cases", familyId = "notes", name = "收下批注医案", minTier = 0, maxTier = 0, cost = { money = 0, grain = 0 }, workYears = 0, sealsRelic = false, claimKey = "notes.first_acquired", cooldownYears = 0, requirements = Requirements({ doctorJobYears = 6, currentUser = { adult = true, alive = true, job = "doctor", stat = { id = "medicine", min = 55 } }, claimUnused = true, immediate = true }), preview = { outcome = "即时取得一阶批注医案；不额外给医术" } },
    { id = "notes.record_case", familyId = "notes", name = "补记一例", tiers = { 1, 2, 3 }, cost = { money = 4, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "notes.record_case", cooldownYears = 2, requirements = Requirements({ adult = true, alive = true, job = "doctor", stat = { id = "medicine", min = 55 }, available = true, uniqueCase = true }), preview = { cost = "现在付4两", outcome = "1年后办理人医术+3、声望+2，写入独立病例；完成后冷却2年" } },
    { id = "notes.upgrade_2", familyId = "notes", name = "校订医案", tiers = { 1 }, cost = { money = 12, grain = 0 }, workYears = 1, sealsRelic = true, claimKey = "notes.upgraded_2", cooldownYears = 0, requirements = Requirements({ useYears = 3, cases = 1, adult = true, alive = true, job = "doctor", stat = { id = "medicine", min = 60 } }), preview = { outcome = "原实例升二阶；封存一年，完成后医术年度加成为+3" } },
    { id = "notes.upgrade_3", familyId = "notes", name = "三阶编订", tiers = { 2 }, cost = { money = 20, grain = 0 }, workYears = 1, sealsRelic = true, claimKey = "notes.upgraded_3", cooldownYears = 0, requirements = Requirements({ useYears = 6, generations = 2, cases = 2, adult = true, alive = true, job = "doctor", stat = { id = "medicine", min = 70 }, chooseBeforeAccept = true }), branches = { private = { resultFormId = "notes.3.private", medicine = 4, reputation = 0, fact = "medical_cases_private" }, public = { resultFormId = "notes.3.public", medicine = 2, reputation = 12, fact = "medical_cases_published", unlockAction = "notes.public_clinic" } }, preview = { outcome = "家传：医术+4/年；刊行：医术+2/年、当次声望+12并开放义诊" } },
    { id = "notes.public_clinic", familyId = "notes", name = "应邀义诊", tiers = { 3 }, cost = { money = 8, grain = 0 }, workYears = 1, sealsRelic = false, claimKey = "notes.public_clinic", cooldownYears = 5, requirements = Requirements({ branch = "public", adult = true, alive = true, job = "doctor", stat = { id = "medicine", min = 60 }, available = true }), preview = { cost = "现在付8两", outcome = "1年后声望+8、办理人医术+1；无现金收入，冷却5年" } },
}

local formById = {}
local actionById = {}
local familyById = {}
local legacyFormById = {}
for _, family in ipairs(Definitions.Families) do familyById[family.id] = family end
for _, form in ipairs(Definitions.Forms) do
    formById[form.id] = form
    if form.legacyId and legacyFormById[form.legacyId] == nil then legacyFormById[form.legacyId] = form end
end
for _, action in ipairs(Definitions.Actions) do actionById[action.id] = action end

function Definitions.Form(id)
    return formById[id]
end

function Definitions.Action(id)
    return actionById[id]
end

function Definitions.Family(id)
    return familyById[id]
end

function Definitions.LegacyForm(id)
    return legacyFormById[id] or formById[id]
end

return Definitions
