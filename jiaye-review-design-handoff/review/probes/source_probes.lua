-- Isolated probes of verbatim function excerpts fetched via GitHub connector.
-- Commit: 546ff6cf7e4225632fe9871ba70188e6aa730e82
-- This does NOT launch UrhoX or test the full application.
local State, Simulation, App, Data = {}, {}, {}, {}
local results = {}
local function test(id, issue, observed, expected, condition)
    results[#results+1] = {id, issue, observed, expected, condition}
    print(id .. '\t' .. (condition and 'ISSUE_REPRODUCED' or 'NOT_REPRODUCED') .. '\t' .. issue .. '\t' .. observed .. '\t' .. expected)
end
-- State.lua / State.Copy, State.FindMember, State.Generation, State.AddLog (unchanged)
function State.Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[State.Copy(key)] = State.Copy(item) end
    return copy
end
function State.FindMember(members, id)
    for _, member in ipairs(members) do if member.id == id then return member end end
    return nil
end
function State.Generation(members, memberId, visited)
    local member = State.FindMember(members, memberId)
    if not member then return 1 end
    visited = visited or {}
    if visited[memberId] then return 1 end
    visited[memberId] = true
    local generation = 1
    for _, parentId in ipairs(member.parents or {}) do
        generation = math.max(generation, State.Generation(members, parentId, visited) + 1)
    end
    visited[memberId] = nil
    return generation
end
function State.AddLog(run, text)
    table.insert(run.logs, 1, { year = run.calendar, text = text })
    while #run.logs > 120 do table.remove(run.logs) end
end
-- App.lua / App:UndoPage (unchanged); UI methods stubbed only in fixture.
function App:UndoPage(page)
    if not self.undo[page] then self:Notify("本页没有可撤销的随机结果。", "warning"); return end
    self.draft = self.undo[page]; self.undo[page] = nil; self.openingFeedback = "已恢复随机前的本页配置。"; self:Render()
end
-- Simulation.lua / JobGenerations (unchanged)
local function JobGenerations(run, jobId, years)
    local generations = {}
    for _, member in ipairs(run.members) do
        if (member.jobYears[jobId] or 0) >= years then
            local generation = State.Generation(run.members, member.id)
            generations[generation] = true
        end
    end
    local count = 0
    for _ in pairs(generations) do count = count + 1 end
    return count
end
-- Dependency fixture: only tested Home has upkeep=0.
Data.Home = function() return {upkeep=0} end
-- Simulation.lua / ResolveLivingCosts (unchanged)
local function ResolveLivingCosts(run, living, period, place)
    local home = Data.Home(run.homeId)
    local baseExpense, carers = home.upkeep, 0
    for _, member in ipairs(living) do
        baseExpense = baseExpense + (member.age >= 18 and 4 or 2)
        if member.jobId == "home" then carers = carers + 1 end
    end
    local expense = math.floor(baseExpense * period.expense * (place.expenseMultiplier or 1))
    expense = math.max(0, expense - carers * 3)
    if run.habitId == "frugal" then expense = math.floor(expense * 0.9) end
    run.money = run.money - expense
    local foodNeed = 0
    for _, member in ipairs(living) do foodNeed = foodNeed + (member.age >= 18 and 2 or 1) end
    if run.grain >= foodNeed then run.grain = run.grain - foodNeed; run.metrics.foodYears = run.metrics.foodYears + 1 else
        local missing = foodNeed - run.grain; run.grain = 0
        local price = math.ceil(period.food * missing * (place.foodMultiplier or 1))
        if run.money >= price then
            run.money = run.money - price; run.metrics.foodYears = run.metrics.foodYears + 1
        else
            run.money = math.max(0, run.money)
            for _, member in ipairs(living) do member.health = math.max(0, member.health - 12) end
            State.AddLog(run, "口粮不足，全家体魄各减 12 点，度过了艰难的一年。")
        end
    end
    if run.money < 0 and run.grain > 0 then
        local sold = math.min(run.grain, math.ceil(-run.money / period.food))
        run.grain = run.grain - sold; run.money = run.money + sold * period.food
        State.AddLog(run, "卖出 " .. tostring(sold) .. " 石粮以补足日常开支。")
    end
    if run.money >= 0 then run.metrics.stable = run.metrics.stable + 1 else run.metrics.stable = 0 end
end
-- Simulation.lua / HasRelic, AgeAndLife, AppointLeader, ResolveLeaderEvent (unchanged)
local function HasRelic(run, relicId)
    for _, instance in ipairs(run.relicInstances) do
        if instance.definitionId == relicId and instance.status ~= "sold" then return instance end
    end
    return nil
end
local function AgeAndLife(run, living)
    for _, member in ipairs(living) do
        member.age = member.age + 1
        local danger = member.age >= 82 and (member.age - 80) * 0.04 or (member.age >= 68 and (member.age - 67) * 0.008 or 0)
        if member.health < 20 then danger = danger + 0.05 end
        if State.Random(run) < danger then
            member.alive = false
            for _, relic in ipairs(run.relicInstances) do if relic.custodianId == member.id and relic.status ~= "sold" then relic.custodianId = run.leaderId end end
            State.AddLog(run, member.name .. "于大晟历 " .. tostring(run.calendar) .. " 年离世，生平被保留在家谱中。")
        end
    end
end
function Simulation.AppointLeader(run, memberId, reason)
    if run.ending then return false, "本局已落笔。" end
    local target = State.FindMember(run.members, memberId)
    if not target or not target.alive or target.age < 18 then return false, "族长必须是在世成年族人。" end
    if run.leaderId == memberId then return false, "此人已是族长。" end
    local old = State.FindMember(run.members, run.leaderId)
    local wasEffective = false
    for _, term in ipairs(run.leaderTerms) do
        if term.memberId == run.leaderId and not term.endYear then
            term.endYear = run.yearIndex
            term.effective = run.yearIndex - term.startYear >= 1
            wasEffective = term.effective
        end
    end
    local effective = false
    table.insert(run.leaderTerms, { memberId = memberId, startYear = run.yearIndex, endYear = nil, effective = effective, reason = reason or "主动交接" })
    run.leaderId = memberId
    if HasRelic(run, "newbook") and old and wasEffective then
        run.reputation = run.reputation + 3
        State.AddLog(run, "补完的族谱为这次有效交接添了 3 点声望。")
    end
    State.AddLog(run, (old and old.name or "前任") .. "将族长之位交给了" .. target.name .. "。")
    return true, "族长已更替，其他族人的安排保持不变。"
end
function Simulation.ResolveLeaderEvent(run, eventId, memberId)
    local event = nil; for _, item in ipairs(run.events) do if item.instanceId == eventId then event = item end end
    if not event or event.type ~= "leader" or event.status ~= "pending" then return false, "继任事件已失效。" end
    local ok, message = Simulation.AppointLeader(run, memberId, "前任离世")
    if ok then event.status = "resolved" end
    return ok, message
end
-- Fixtures / probes
local r = {logs={}, calendar=72}
for i=1,121 do State.AddLog(r,'entry-'..i) end
test('P01','long_history_deleted','length='..#r.logs..'; oldest='..r.logs[#r.logs].text,'121 retained; entry-1 retrievable',#r.logs==120 and r.logs[#r.logs].text=='entry-2')
local a = setmetatable({draft={money=180,originId='plain'},undo={world={money=80,originId='artisan'}},Notify=function() end,Render=function() end}, {__index=App})
a:UndoPage('world')
test('P02','page_undo_overwrites_other_page','money='..a.draft.money..'; origin='..a.draft.originId,'money=180; origin=artisan',a.draft.money==80)
local starving = {money=-10,grain=0,homeId='simple',habitId='none',metrics={stable=4,foodYears=7},logs={},calendar=72}
local starvingMember = {age=30,jobId='study',health=60}
ResolveLivingCosts(starving,{starvingMember},{expense=1,food=2},{})
test('P03','starvation_counts_as_stable','health='..starvingMember.health..'; stable='..starving.metrics.stable,'health drops; stable resets to 0',starvingMember.health==48 and starving.metrics.stable==5)
test('P04','consecutive_food_not_reset','foodYears='..starving.metrics.foodYears,'foodYears=0 after starvation',starving.metrics.foodYears==7)
local generationsRun={members={{id=1,parents={},jobYears={},generation=1},{id=2,parents={1},spouseId=3,jobYears={teach=2},generation=2},{id=3,parents={},spouseId=2,jobYears={teach=2},generation=2}}}
local g=JobGenerations(generationsRun,'teach',2)
test('P05','married_in_member_generation_mismatch','same-generation couple counted as '..g..' generations','1 generation for two generation-2 members',g==2)
State.Random=function() return 0 end -- deterministic test RNG, not actual PRNG behavior under test
local deathRun={members={{id=1,name='Founder',age=89,health=60,alive=true},{id=2,name='Successor',age=30,health=76,alive=true}},leaderId=1,relicInstances={{definitionId='ruler',status='held',custodianId=1}},logs={},calendar=72}
AgeAndLife(deathRun,deathRun.members)
test('P06','dead_leader_remains_relic_custodian','leaderAlive='..tostring(deathRun.members[1].alive)..'; custodian='..deathRun.relicInstances[1].custodianId,'house custody or a living person',deathRun.members[1].alive==false and deathRun.relicInstances[1].custodianId==1)
local succession={members={{id=1,name='Old',age=80,alive=false},{id=2,name='New',age=30,alive=true}},leaderId=1,leaderTerms={{memberId=1,startYear=0}},events={{instanceId='leader-event',type='leader',status='pending'}},relicInstances={},logs={},calendar=90,yearIndex=18,reputation=0}
local appointOk=Simulation.AppointLeader(succession,2,'manual')
local resolveOk,msg=Simulation.ResolveLeaderEvent(succession,'leader-event',2)
test('P07','manual_succession_leaves_blocking_event','manual='..tostring(appointOk)..'; resolve='..tostring(resolveOk)..'; status='..succession.events[1].status,'one successor chosen; leader event resolved',appointOk and not resolveOk and succession.events[1].status=='pending')
-- Verbatim one-line expression from State.NewRun, with explicit fixture.
local origin={id='gentry'}; local draft={tieId='neighbor'}
local reputation = origin.id == "gentry" and 25 or (draft.tieId == "neighbor" and 12 or 0)
test('P08','paid_reputation_options_do_not_stack','reputation='..reputation,'37 from documented +25 and +12',reputation==25)
print('TOTAL\t'..#results)
