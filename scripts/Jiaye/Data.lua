local Data = {}

Data.LIMIT = 100
Data.WORLD_NAME = "大晟"
Data.RULES_VERSION = 1

Data.Periods = {
    { id = "rebuild", name = "乱后重建", era = "rebuild", years = { 12, 24, 36 }, cost = 8, wage = 1.00, food = 2, expense = 1.00, desc = "乱后初定，谋生与学艺都不容易，也都有机会。" },
    { id = "peace", name = "安定盛年", era = "peace", years = { 48, 60, 72 }, cost = 12, wage = 1.05, food = 2, expense = 1.00, desc = "道路通畅，乡里安稳。" },
    { id = "strain", name = "盛世渐晚", era = "strain", years = { 96, 108, 120 }, cost = 4, wage = 1.00, food = 3, expense = 1.10, desc = "物价慢慢上涨，过日子要多留一份心。" },
    { id = "unrest", name = "变局将至", era = "unrest", years = { 132, 144, 156 }, cost = 0, wage = 0.85, food = 4, expense = 1.05, desc = "商路时通时断，先安顿下来，再想明天。" },
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
    { id = "village", name = "河畔乡村", short = "青石村", cost = 0, desc = "收益：耕作每年多收 2 石粮。", burden = "代价：非耕作收入 -8%。", incomeMultiplier = 0.92 },
    { id = "mountain", name = "山间小镇", short = "青岚镇", cost = 2, desc = "收益：手艺、行医收入 +10%。", burden = "代价：耕作每年少收 2 石粮。", farmGrainModifier = -2 },
    { id = "border", name = "边地驿镇", short = "北望驿", cost = 3, desc = "收益：护卫收入 +20%。", burden = "代价：生活开支 +8%，全家每年劳损 1 点。", expenseMultiplier = 1.08, healthPenalty = 1 },
    { id = "county", name = "县城近郊", short = "临川县", cost = 7, desc = "收益：读书每年额外学识 +1。", burden = "代价：生活开支 +15%。", expenseMultiplier = 1.15 },
    { id = "port", name = "江口商埠", short = "江口埠", cost = 10, desc = "收益：经商收入 +20%。", burden = "代价：生活开支 +20%，缺粮时购粮价 +10%。", expenseMultiplier = 1.20, foodMultiplier = 1.10 },
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
    study = { name = "读书求学", min = 5, money = -6, stat = "learn", gain = 5, desc = "每年花费 6 两，积累学识。" },
    farm = { name = "耕作谋生", min = 18, money = 8, grain = 6, desc = "每年收入 8 两、收粮 6 石。" },
    apprentice = { name = "学一门手艺", min = 12, money = -4, stat = "skill", gain = 7, desc = "每年花费 4 两，手艺成长。" },
    craft = { name = "手艺谋生", min = 18, money = 22, stat = "skill", gain = 2, req = { "skill", 35 }, desc = "手艺达到 35 后可谋生。" },
    trade = { name = "外出经商", min = 18, money = 24, stat = "trade", gain = 3, desc = "往来商路，收入受地点与关系影响。" },
    teach = { name = "教书", min = 18, money = 20, stat = "learn", gain = 2, req = { "learn", 50 }, desc = "学识达到 50 后可教书。" },
    medical = { name = "随师学医", min = 12, money = -8, stat = "medicine", gain = 7, desc = "每年花费 8 两，学习医术。" },
    doctor = { name = "行医问诊", min = 18, money = 26, stat = "medicine", gain = 3, req = { "medicine", 40 }, desc = "医术达到 40 后可行医。" },
    train = { name = "习武", min = 12, money = -5, stat = "martial", gain = 7, desc = "每年花费 5 两，锤炼武艺。" },
    guard = { name = "担任护卫", min = 18, money = 22, stat = "martial", gain = 3, req = { "martial", 35 }, desc = "武艺达到 35 后可护卫。" },
    official = { name = "地方任职", min = 18, money = 32, stat = "learn", gain = 1, exam = true, desc = "应试通过后可任职，提升声望。" },
    home = { name = "料理家事", min = 18, money = 0, desc = "照料全家，减少开支并恢复体魄。" },
    rest = { name = "休养", min = 0, money = 0, stat = "health", gain = 5, desc = "恢复体魄，衰老仍会继续。" },
}

Data.Homes = {
    { id = "rented", name = "租下两间房", cost = 0, upkeep = 4 },
    { id = "simple", name = "自家土屋", cost = 6, upkeep = 0 },
    { id = "courtyard", name = "一方小院", cost = 14, upkeep = 0 },
    { id = "estate", name = "旧宅深院", cost = 28, upkeep = 0 },
}

Data.Habits = {
    { id = "none", name = "各自舒展", cost = 0 }, { id = "frugal", name = "节用惜物", cost = 5 },
    { id = "education", name = "不废灯火", cost = 5 }, { id = "care", name = "彼此照应", cost = 5 },
}

Data.Ties = {
    { id = "none", name = "初来乍到", cost = 0 }, { id = "teacher", name = "一位师友", cost = 6 },
    { id = "healer", name = "医馆旧识", cost = 6 }, { id = "partner", name = "商路故交", cost = 6 },
    { id = "neighbor", name = "乡里相熟", cost = 6 },
}

Data.Relics = {
    { id = "book", name = "一本旧族谱", cost = 6, basic = true, unlock = "newbook", event = "book", desc = "折起的一页，等待被重新读懂。" },
    { id = "ruler", name = "一把老木尺", cost = 6, basic = true, unlock = "plan", event = "ruler", desc = "尺背有陌生的匠号。" },
    { id = "letter", name = "一封未拆的家书", cost = 4, basic = true, unlock = "jade", event = "letter", desc = "有人曾说，等日子安稳了再送到。" },
    { id = "plan", name = "修复的营造图", cost = 10, unlock = nil, event = "plan", desc = "可接下修缮工作，增进手艺路线。" },
    { id = "newbook", name = "补完的族谱", cost = 9, unlock = nil, event = "newbook", desc = "空着的一行终于写回名字。" },
    { id = "jade", name = "故人的半枚玉佩", cost = 8, unlock = nil, event = "jade", desc = "另一半不在这里。" },
    { id = "notes", name = "批注医案", cost = 10, unlock = nil, event = "notes", desc = "一页页认真记下的诊治经验。" },
}

Data.Endings = {
    { id = "peaceful", title = "炊烟未断", desc = "把安稳的日子接过了两任人手。" },
    { id = "scholar", title = "书香传家", desc = "两代人都把书教给别人。" },
    { id = "merchant", title = "商脉长存", desc = "另一代人稳稳接过账册。" },
    { id = "craft", title = "百年手艺", desc = "技艺在不同的人手里继续生长。" },
    { id = "medical", title = "杏林人家", desc = "药箱与耐心一起传给后来人。" },
    { id = "grain", title = "四时有余", desc = "过冬时，孩子不必先说自己不饿。" },
    { id = "community", title = "一村归心", desc = "几次真正伸出的手，留下了分量。" },
    { id = "migration", title = "异乡生根", desc = "在陌生地方把家续了下去。" },
    { id = "return", title = "归来有灯", desc = "走远的人仍有自己的位置。" },
    { id = "promise", title = "迟来的家书", desc = "前人的一句答应，终于被认真完成。" },
    { id = "ruler", title = "木尺新纹", desc = "旧尺量过前人的屋，也量过后人的路。" },
    { id = "reunion", title = "家谱再续", desc = "被折起的一页重新展开。" },
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
function Data.Experience(id) return Data.Find(Data.Experiences, id) end
function Data.Home(id) return Data.Find(Data.Homes, id) end
function Data.Habit(id) return Data.Find(Data.Habits, id) end
function Data.Tie(id) return Data.Find(Data.Ties, id) end
function Data.Relic(id) return Data.Find(Data.Relics, id) end
function Data.Ending(id) return Data.Find(Data.Endings, id) end

return Data
