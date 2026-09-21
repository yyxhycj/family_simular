local State = require "Jiaye.State"
local T14 = require "QA.T14FullPaths"

function Start()
    State.UseVerificationStorage("t14")
    T14.Run()
end

function Stop()
end
