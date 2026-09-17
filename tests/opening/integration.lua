local State = require "Jiaye.State"
local App = require "Jiaye.App"
local Opening = require "Jiaye.Opening"
local Economy = require "Jiaye.Economy"
local Sim = require "Jiaye.Simulation"
local same = Opening.Equal
local function find(root, label)
    if root.text == label then return root end
    for _, child in ipairs(root.children or {}) do local found = find(child,label); if found then return found end end
end
return {
    run = function()
        local profile, oldDraft = State.NewProfile(), State.NewDraft()
        local oldRun = assert(State.NewRun(oldDraft,profile))
        assert(State.Save(profile,oldDraft,oldRun))
        local app = App.New(); app:PrepareNewRun()
        local candidate = State.Copy(app.draft)
        for _, view in ipairs({"summary","ledger","points","people","relics"}) do
            app.openingView = view; app:Render()
            assert(same(candidate,app.draft),"view rerolled or edited draft: " .. view)
        end
        assert(same(State.Load().run,oldRun),"candidate browsing changed prior save")
        app:CancelNewRun(); assert(same(oldDraft,app.draft) and same(oldRun,app.run))
        app:PrepareNewRun(); candidate=State.Copy(app.draft)
        local displayedRun=assert(State.NewRun(candidate,profile))
        local forecast=Economy.Preview(displayedRun)
        app:StartRun(); local cancel=assert(find(UI.modal,"取消")); cancel.onClick(cancel)
        assert(same(State.Load().run,oldRun) and same(candidate,app.draft))
        app:StartRun(); local confirm=assert(find(UI.modal,"确认开始")); confirm.onClick(confirm)
        local created=State.Copy(app.run); confirm.onClick(confirm)
        assert(same(created,app.run) and same(candidate,app.run.openingSnapshot))
        assert(same(State.Load().run,app.run) and same(State.Load().draft,app.draft))
        assert(same(forecast,Economy.Preview(app.run)))
        local beforePreview=State.Copy(app.run)
        Economy.Preview(app.run); assert(same(beforePreview,app.run))
        app:RunAction(function() return Sim.AdvanceYear(app.run,app.profile) end)
        assert(same(forecast,app.run.lastLedger),"annual ledger diverged from displayed forecast")
        assert(same(State.Load().run,app.run))
        return {points=State.TotalPoints(candidate),snapshot=candidate,ledger=forecast,
            priorSaveRetainedUntilConfirmation=true,readOnlyViews=5,duplicateConfirmationIgnored=true}
    end,
    restart = function()
        local app=App.New(); app:Load()
        assert(app.run and app.run.yearIndex==1 and app.run.lastLedger)
        assert(same(app.run.openingSnapshot,app.draft) and same(State.Load().run,app.run))
        return {family=app.draft.family,year=app.run.yearIndex,points=State.TotalPoints(app.draft),ledger=app.run.lastLedger}
    end,
}
