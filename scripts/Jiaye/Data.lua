local Data = {}

Data.LIMIT = 100
Data.OpeningCosts = { moneyUnit = 10, grainUnit = 4, land = 4, workshop = 14, shop = 20 }
-- 运行中置办保留既有价格；界面与结算动作只读取这里，开局点数不复用这组银两。
Data.RuntimeAssetCosts = { land = 30, workshop = 80, shop = 120 }
Data.FocusNames = { general = "均衡", learn = "学识", skill = "手艺", medicine = "医术", trade = "经营", martial = "武艺" }
Data.JobOrder = { "play", "study", "farm", "apprentice", "craft", "trade", "teach", "medical", "doctor", "train", "guard", "official", "home", "rest" }
Data.AgeRules = {
    basicExperience = 8,
    study = 5,
    training = 12,
    adult = 18,
    parentDifference = 18,
    birth = { min = 21, max = 60 },
}
Data.WORLD_NAME = "大晟"
-- V7 改变了开局背景与局内家风的语义；旧 run 继续读取自身的 rulesVersion。
Data.RULES_VERSION = 2

Data.Periods = {
    { id = "rebuild", name = "百废初兴", era = "rebuild", years = { 12, 24, 36 }, cost = 8, wage = 1.00, food = 2, expense = 1.00, desc = "乱后初定，谋生与学艺都不容易，也都有机会。" },
    { id = "peace", name = "承平岁月", era = "peace", years = { 48, 60, 72 }, cost = 12, wage = 1.05, food = 2, expense = 1.00, desc = "道路通畅，乡里安稳。" },
    { id = "strain", name = "繁华之下", era = "strain", years = { 96, 108, 120 }, cost = 4, wage = 1.00, food = 3, expense = 1.10, desc = "物价慢慢上涨，过日子要多留一份心。" },
    { id = "unrest", name = "风雨欲来", era = "unrest", years = { 132, 144, 156 }, cost = 0, wage = 0.85, food = 4, expense = 1.05, desc = "商路时通时断，先安顿下来，再想明天。" },
}

Data.Origins = {
    { id = "plain", name = "布衣农户", cost = 0, desc = "务农族人每年额外收粮 1 石。" },
    { id = "artisan", name = "手艺人家", cost = 8, desc = "学手艺、手艺谋生每年额外手艺 +1。" },
    { id = "merchant", name = "行商后裔", cost = 12, desc = "经商收入 +10%。" },
    { id = "scholar", name = "书香旧族", cost = 16, desc = "读书每年额外学识 +2。" },
    { id = "military", name = "军户后人", cost = 10, desc = "习武每年额外武艺 +2；护卫收入 +10%。" },
    { id = "gentry", name = "旧日名门", cost = 26, desc = "初始声望 +25；每年声望 +1。" },
}

Data.Places = {
    { id = "village", name = "河畔乡村", short = "青石村", cost = 0, desc = "收益：耕作每年多收 2 石粮。", burden = "代价：非耕作收入 -5%。", incomeMultiplier = 0.95 },
    { id = "mountain", name = "山间小镇", short = "青岚镇", cost = 2, desc = "收益：手艺、行医收入 +10%。", burden = "代价：耕作每年少收 1 石粮。", farmGrainModifier = -1 },
    { id = "border", name = "边地驿镇", short = "北望驿", cost = 3, desc = "收益：护卫收入 +20%。", burden = "代价：生活开支 +5%。", expenseMultiplier = 1.05 },
    { id = "county", name = "县城近郊", short = "临川县", cost = 7, desc = "收益：读书每年额外学识 +1。", burden = "代价：生活开支 +15%。", expenseMultiplier = 1.15 },
    { id = "port", name = "江口商埠", short = "江口埠", cost = 10, desc = "收益：经商收入 +20%。", burden = "代价：生活开支 +15%。", expenseMultiplier = 1.15 },
}

-- 新开局使用背景定义承接来历、地区历史和旧识叙事。
-- opportunity 的价格和结果仍待确认，原型阶段不向经济结算注入新奖励。
Data.Backgrounds = {
    {
        id = "plain_village", name = "河畔农家", originId = "plain", cost = 0,
        history = "家中熟悉水土与农时，在河畔乡里守着一块薄田。",
        contacts = { { id = "zhou_boqu", name = "周伯渠", relation = "河埠老农", history = "每逢汛期替乡里传递农时消息。" } },
        effect = { description = "务农族人每年额外收粮 1 石。", condition = "在世族人当前安排为耕作。", source = "Data.Origins.plain" },
        opportunity = { id = "plain_harvest", name = "河埠换种", status = "prototype", condition = "需要在世耕作者并完成一段真实农事经历。", cost = nil, result = nil, pending = "费用与结果待确认；原型阶段不扣款、不改变年度结算。" },
    },
    {
        id = "artisan_workshop", name = "手艺人家", originId = "artisan", cost = 8,
        history = "家中有人靠手艺度日，旧工具和师承仍留在手边。",
        contacts = { { id = "shen_musheng", name = "沈木生", relation = "旧匠坊师兄", history = "曾与家中手艺人同在一间匠坊学艺。" } },
        effect = { description = "学手艺、手艺谋生每年额外手艺 +1。", condition = "族人当前安排为学手艺或手艺谋生。", source = "Data.Origins.artisan" },
        opportunity = { id = "artisan_repair", name = "旧坊修缮", status = "prototype", condition = "需要在世手艺人当前安排为手艺谋生，并有可追溯的作坊经历。", cost = nil, result = nil, pending = "费用与结果待确认；原型阶段不扣款、不改变年度结算。" },
    },
    {
        id = "merchant_route", name = "行商后裔", originId = "merchant", cost = 12,
        history = "家中记得几条旧商路，往来见闻比田地更熟。",
        contacts = { { id = "gu_jiuru", name = "顾九如", relation = "南来商行掌柜", history = "家中长辈曾在南来商行留下账册。" } },
        effect = { description = "经商收入 +10%。", condition = "族人当前安排为外出经商。", source = "Data.Origins.merchant" },
        opportunity = { id = "merchant_credit", name = "旧账重开", status = "prototype", condition = "需要在世经商者、实际商路经历和有效账本记录。", cost = nil, result = nil, pending = "费用与结果待确认；原型阶段不扣款、不改变年度结算。" },
    },
    {
        id = "scholar_lineage", name = "书香旧族", originId = "scholar", cost = 16,
        history = "旧书和家训尚在，家中仍有人愿意从灯下读起。",
        contacts = { { id = "lu_yanshan", name = "陆砚山", relation = "塾中旧友", history = "曾与家中读书人共同抄录旧籍。" } },
        effect = { description = "读书每年额外学识 +2。", condition = "族人当前安排为读书求学。", source = "Data.Origins.scholar" },
        opportunity = { id = "scholar_archive", name = "旧卷借阅", status = "prototype", condition = "需要在世读书者和连续读书的真实家史记录。", cost = nil, result = nil, pending = "费用与结果待确认；原型阶段不扣款、不改变年度结算。" },
    },
    {
        id = "military_post", name = "军户后人", originId = "military", cost = 10,
        history = "家中熟悉守备与操练，仍记得旧营地的规矩。",
        contacts = { { id = "cheng_shouyi", name = "程守义", relation = "驿站故人", history = "家中长辈曾替驿站守过一段路。" } },
        effect = { description = "习武每年额外武艺 +2；护卫收入 +10%。", condition = "族人当前安排为习武或担任护卫。", source = "Data.Origins.military" },
        opportunity = { id = "military_escort", name = "旧营护送", status = "prototype", condition = "需要在世护卫者和已发生的护卫经历。", cost = nil, result = nil, pending = "费用与结果待确认；原型阶段不扣款、不改变年度结算。" },
    },
    {
        id = "gentry_old_house", name = "旧日名门", originId = "gentry", cost = 26,
        history = "旧宅与名望都已褪色，留下的是需要重新经营的家史。",
        contacts = { { id = "wen_jingxiu", name = "闻敬修", relation = "旧门房", history = "仍替家中保管一册未完的旧客名录。" } },
        effect = { description = "初始声望 +25；每年声望 +1。", condition = "开局写入初始声望，年度结算保留既有声望增长。", source = "Data.Origins.gentry" },
        opportunity = { id = "gentry_reputation", name = "旧客重访", status = "prototype", condition = "需要真实接待或互助事实，具体事件条件待确认。", cost = nil, result = nil, pending = "费用与结果待确认；原型阶段不扣款、不改变年度结算。" },
    },
}

-- 由实际生活形成的家风只记录事实，不在原型阶段添加属性修正。
Data.HabitFormations = {
    education = { id = "education", name = "不废灯火", threshold = 3, trigger = "连续三年有人读书", lossThreshold = 0, effect = "none", prototype = true },
}

Data.Surnames = { "林", "沈", "顾", "陆", "程", "许", "周", "宋", "苏", "叶", "闻", "姜" }
Data.GivenNames = {
    male = { "成", "安", "远", "砚", "衡", "川", "允", "修", "明", "知" },
    female = { "青", "芸", "宁", "禾", "昭", "瑶", "微", "晚", "棠", "绮" },
}

Data.Talents = {
    { name = "慢热", cost = 0, gain = -1 }, { name = "平常", cost = 1, gain = 0 },
    { name = "灵秀", cost = 3, gain = 1 }, { name = "出众", cost = 7, gain = 3 },
    { name = "罕见", cost = 14, gain = 5 },
}

Data.Experiences = {
    { id = "none", name = "尚未专精", cost = 0, values = { learn = 10, skill = 10, medicine = 0, trade = 10, martial = 10 } },
    { id = "basic", name = "略通一二", cost = 3, values = { learn = 25, skill = 25, medicine = 10, trade = 10, martial = 10 } },
    { id = "craft", name = "熟练手艺", cost = 8, values = { learn = 15, skill = 50, medicine = 0, trade = 15, martial = 10 } },
    { id = "scholar", name = "读过诗书", cost = 9, values = { learn = 60, skill = 10, medicine = 0, trade = 10, martial = 10 } },
    { id = "medical", name = "行医经验", cost = 8, values = { learn = 30, skill = 10, medicine = 45, trade = 10, martial = 10 } },
    { id = "trade", name = "经商经验", cost = 8, values = { learn = 20, skill = 10, medicine = 0, trade = 50, martial = 10 } },
    { id = "martial", name = "练过拳脚", cost = 8, values = { learn = 10, skill = 15, medicine = 0, trade = 10, martial = 50 } },
}

Data.Jobs = {
    play = { name = "随家人生活", min = 0, money = 0, desc = "没有收入，也不花培养费用。" },
    study = { name = "读书求学", min = Data.AgeRules.study, money = -6, stat = "learn", gain = 5, desc = "每年花费 6 两，积累学识。" },
    farm = { name = "耕作谋生", min = Data.AgeRules.adult, money = 8, grain = 6, desc = "每年收入 8 两、收粮 6 石。" },
    apprentice = { name = "学一门手艺", min = Data.AgeRules.training, money = -4, stat = "skill", gain = 7, desc = "每年花费 4 两，手艺成长。" },
    craft = { name = "手艺谋生", min = Data.AgeRules.adult, money = 22, stat = "skill", gain = 2, req = { "skill", 35 }, desc = "手艺达到 35 后可谋生。" },
    trade = { name = "外出经商", min = Data.AgeRules.adult, money = 24, stat = "trade", gain = 3, desc = "往来商路，收入受地点与关系影响。" },
    teach = { name = "教书", min = Data.AgeRules.adult, money = 20, stat = "learn", gain = 2, req = { "learn", 50 }, desc = "学识达到 50 后可教书。" },
    medical = { name = "随师学医", min = Data.AgeRules.training, money = -8, stat = "medicine", gain = 7, desc = "每年花费 8 两，学习医术。" },
    doctor = { name = "行医问诊", min = Data.AgeRules.adult, money = 26, stat = "medicine", gain = 3, req = { "medicine", 40 }, desc = "医术达到 40 后可行医。" },
    train = { name = "习武", min = Data.AgeRules.training, money = -5, stat = "martial", gain = 7, desc = "每年花费 5 两，锤炼武艺。" },
    guard = { name = "担任护卫", min = Data.AgeRules.adult, money = 22, stat = "martial", gain = 3, req = { "martial", 35 }, desc = "武艺达到 35 后可护卫。" },
    official = { name = "地方任职", min = Data.AgeRules.adult, money = 32, stat = "learn", gain = 1, exam = true, desc = "应试通过后可任职，提升声望。" },
    home = { name = "料理家事", min = Data.AgeRules.adult, money = 0, desc = "照料全家，减少开支并恢复体魄。" },
    rest = { name = "休养", min = 0, money = 0, stat = "health", gain = 5, desc = "恢复体魄，衰老仍会继续。" },
}

Data.Homes = {
    { id = "rented", name = "租下两间房", cost = 0, upkeep = 4 },
    { id = "simple", name = "自家土屋", cost = 6, upkeep = 0 },
    { id = "courtyard", name = "一方小院", cost = 14, upkeep = 0 },
    { id = "estate", name = "旧宅深院", cost = 28, upkeep = 0 },
}

Data.Habits = {
    { id = "none", name = "各自舒展", cost = 0, desc = "没有额外的年度修正。" }, { id = "frugal", name = "节用惜物", cost = 5, desc = "全家日常开支 -10%。" },
    { id = "education", name = "不废灯火", cost = 5, desc = "读书每年额外学识 +1。" }, { id = "care", name = "彼此照应", cost = 5, desc = "休养每年额外恢复体魄 +2。" },
}

Data.Ties = {
    { id = "none", name = "初来乍到", cost = 0, desc = "没有额外的人情便利。" }, { id = "teacher", name = "一位师友", cost = 6, desc = "读书每年额外学识 +1，教书收入 +2 两。" },
    { id = "healer", name = "医馆旧识", cost = 6, desc = "学医每年额外医术 +1，行医收入 +2 两。" }, { id = "partner", name = "商路故交", cost = 6, desc = "经商收入 +3 两。" },
    { id = "neighbor", name = "乡里相熟", cost = 6, desc = "初始声望 +12，接济邻里额外声望 +2。" },
}

Data.Relics = {
    { id = "book", name = "一本旧族谱", cost = 6, saleValue = 12, basic = true, unlock = "newbook", event = "book", desc = "折起的一页，等待被重新读懂。核对遗漏记载后补出一本族谱。", story = { source = "开局带入", executor = "校谱人", title = "族谱里缺失的一页", body = "整理旧谱时，家人发现中间少了一页。下一页的角上，写着一个陌生的小名。也许还有一支亲人，很久没有回家。", fast = { label = "前往邻村核对记载" }, slow = { label = "逐页校勘" }, restore = "重修入谱", defer = "保留缺页" } },
    { id = "ruler", name = "一把老木尺", cost = 6, saleValue = 14, basic = true, unlock = "plan", event = "ruler", desc = "尺背有陌生的匠号。查明匠号后寻回一张营造图。", story = { source = "开局带入", executor = "调查者", title = "木尺上的旧刻痕", body = "修补桌脚时，木尺背面那枚浅浅的匠号又露了出来。镇上老匠说，旧祠堂里或许还留着那个人的图。", fast = { label = "带着木尺，去旧祠堂问问" }, slow = { label = "托旧识慢慢查访" }, restore = "修复图样", defer = "交给当地匠人" } },
    { id = "letter", name = "一封未拆的家书", cost = 4, saleValue = 6, basic = true, unlock = "jade", event = "letter", desc = "有人曾说，等日子安稳了再送到。寻访故人后辈后完成旧约。", story = { source = "开局带入", executor = "送信人", title = "一封未拆的家书", body = "那封家书从未拆开。落款处的人早已不在，收信人却仍可能有后辈。有人想把这句旧日承诺送到。", fast = { label = "出门寻访收信人" }, slow = { label = "托人递送" }, restore = "完成旧约", defer = "把家书暂存" } },
    { id = "plan", name = "修复的营造图", cost = 10, saleValue = 30, unlock = nil, event = "plan", desc = "家中有手艺人时，每年额外得 5 两；还会带来修缮活。", story = { source = "修复老木尺", executor = "匠作负责人", action = "接下修缮活" } },
    { id = "newbook", name = "补完的族谱", cost = 9, saleValue = 18, unlock = nil, event = "newbook", desc = "一次有效交接额外获得 3 点声望，可邀请成年旁支归家。", story = { source = "重修旧族谱", executor = "寻亲人", action = "邀请成年旁支归家" } },
    { id = "jade", name = "故人的半枚玉佩", cost = 8, saleValue = 28, unlock = nil, event = "jade", desc = "可继续查访失散故人，完成一次家谱重逢。", story = { source = "完成一封旧约", executor = "查访人", action = "查访另一半" } },
    { id = "notes", name = "批注医案", cost = 10, saleValue = 24, unlock = nil, event = "notes", desc = "实际行医积累后由医馆托付；可刊印或传给后人。", story = { source = "医馆托付", executor = "行医者", action = "刊印或传承" } },
}

-- 事件纸面、Simulation 和后续 UI 共用这份现有费用与结果定义。
Data.EventChoices = {
    legacy_pending = {
        { id = "acknowledge", label = "写入家史", cost = 0, years = 0, result = { status = "recorded" } },
    },
    leader = {
        { id = "appoint", label = "确认继任", cost = 0, years = 0, result = { status = "recorded" } },
    },
    growth = {
        { id = "defer", label = "暂缓", cost = 0, years = 0, result = { status = "recorded" } },
        { id = "accept", label = "确认成长", cost = 0, years = 0, result = { status = "recorded" } },
    },
    medical_find = {
        { id = "accept", label = "收下医案", cost = 0, years = 0, result = { relicId = "notes", unlock = "notes" } },
        { id = "defer", label = "暂留医馆", cost = 0, years = 0, result = { status = "recorded" } },
    },
    plan_work = {
        { id = "accept", label = "接下修缮", cost = 0, requiredMoney = 10, years = 0, result = { money = 18, reputation = 5 } },
        { id = "defer", label = "暂不接下", cost = 0, years = 0, result = { status = "deferred" } },
    },
    jade_search = {
        { id = "search", label = "查访故人后辈", cost = 8, years = 0, result = { reputation = 8, reunited = true } },
        { id = "defer", label = "暂存线索", cost = 0, years = 0, result = { status = "deferred" } },
    },
    school = {
        { id = "support", label = "添置书本", cost = 6, years = 0, result = { learn = 4 } },
        { id = "defer", label = "暂缓添置", cost = 0, years = 0, result = { status = "deferred" } },
    },
    community_request = {
        { id = "aid", label = "接济邻里", cost = 15, years = 0, result = { reputation = 12, aid = 1 } },
        { id = "defer", label = "暂不接济", cost = 0, years = 0, result = { status = "deferred" } },
    },
    roof = {
        { id = "repair", label = "修补屋顶", cost = 8, years = 0, result = { reputation = 2, homeState = "upgraded" } },
        { id = "defer", label = "暂缓修补", cost = 0, years = 0, result = { homeState = "damaged" } },
    },
    notes_choice = {
        { id = "print", label = "刊印医案", cost = 8, years = 0, result = { reputation = 8, stage = "printed" } },
        { id = "defer", label = "传给后人", cost = 0, years = 0, result = { stage = "passed" } },
    },
    relic_resolution = {
        { id = "restore", label = "完成修复", cost = 0, years = 0, result = { reward = "grant" } },
        { id = "defer", label = "暂存线索", cost = 0, years = 0, result = { reward = "deferred" } },
    },
    relic_investigation = {
        { id = "fast", label = "快速办理", cost = 8, years = 1, result = { stage = "investigating" } },
        { id = "slow", label = "慢查线索", cost = 4, years = 2, result = { stage = "investigating" } },
    },
}

---@class JiayeEndingDefinition
---@field id string
---@field title string
---@field desc string
---@field type string
---@field automatic boolean?
---@field automaticHint string?
---@field automaticTrigger string?
---@field automaticFact string?
---@type JiayeEndingDefinition[]
Data.Endings = {
    { id = "peaceful", title = "炊烟未断", desc = "把安稳的日子接过了两任人手。", type = "development" },
    { id = "scholar", title = "书香传家", desc = "两代人都把书教给别人。", type = "development" },
    { id = "merchant", title = "商脉长存", desc = "另一代人稳稳接过账册。", type = "development" },
    { id = "craft", title = "百年手艺", desc = "技艺在不同的人手里继续生长。", type = "development" },
    { id = "medical", title = "杏林人家", desc = "药箱与耐心一起传给后来人。", type = "development" },
    { id = "grain", title = "四时有余", desc = "过冬时，孩子不必先说自己不饿。", type = "development" },
    { id = "community", title = "一村归心", desc = "几次真正伸出的手，留下了分量。", type = "development" },
    { id = "migration", title = "异乡生根", desc = "在陌生地方把家续了下去。", type = "development" },
    { id = "return", title = "归来有灯", desc = "走远的人仍有自己的位置。", type = "development" },
    { id = "promise", title = "迟来的家书", desc = "前人的一句答应，终于被认真完成。", type = "development" },
    { id = "ruler", title = "木尺新纹", desc = "旧尺量过前人的屋，也量过后人的路。", type = "development" },
    { id = "reunion", title = "家谱再续", desc = "被折起的一页重新展开。", type = "development" },
    { id = "last", title = "家谱落笔", desc = "直到最后一位家人离开，这一局自然写到结尾。", type = "natural", automatic = true, automaticTrigger = "living_members_exhausted", automaticHint = "全体在世族人归零后自动写入", automaticFact = "全员离世，家谱自然落笔。" },
    { id = "collapse", title = "家道散尽", desc = "公库与存粮一同耗尽，家人只得各自另谋生路。", type = "natural", automatic = true, automaticTrigger = "resources_exhausted", automaticHint = "年度结算后公库与存粮同时归零时自动写入", automaticFact = "公库与存粮同时耗尽，家人离散，家谱在此落笔。" },
}

function Data.Find(list, id)
    for _, item in ipairs(list) do if item.id == id then return item end end
    return nil
end

---@param index integer
---@return table<any, any>
function Data.Talent(index) return Data.Talents[index] or Data.Talents[1] end

function Data.Period(id) return Data.Find(Data.Periods, id) end
function Data.Origin(id) return Data.Find(Data.Origins, id) end
function Data.Place(id) return Data.Find(Data.Places, id) end
function Data.Background(id) return Data.Find(Data.Backgrounds, id) end
function Data.BackgroundForOrigin(originId)
    for _, background in ipairs(Data.Backgrounds) do
        if background.originId == originId then return background end
    end
    return nil
end
function Data.Experience(id) return Data.Find(Data.Experiences, id) end
function Data.Home(id) return Data.Find(Data.Homes, id) end
function Data.Habit(id) return Data.Find(Data.Habits, id) end
function Data.Tie(id) return Data.Find(Data.Ties, id) end
function Data.Relic(id) return Data.Find(Data.Relics, id) end
function Data.Ending(id) return Data.Find(Data.Endings, id) end
function Data.HabitFormation(id) return Data.HabitFormations[id] end

function Data.EventChoice(eventType, choiceId)
    for _, choice in ipairs(Data.EventChoices[eventType] or {}) do
        if choice.id == choiceId then return choice end
    end
    return nil
end

return Data
