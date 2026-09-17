local nativeFile, nativeFS = File, fileSystem
local prefix = "/private/tmp/jiaye-t01-engine/savedata/"
File = function(path, mode) return nativeFile(prefix .. path, mode) end
fileSystem = { FileExists = function(_, path) return nativeFS:FileExists(prefix .. path) end }
function Start()
    local ok, message = pcall(function()
        local State = require "Jiaye.State"
        local run = assert(State.NewRun(State.NewDraft(), State.NewProfile()))
        for i = 1, 151 do State.AddLog(run, "entry-" .. tostring(i)) end
        local profile = State.NewProfile(); profile.unlockedRelicIds.plan = true
        assert(State.Save(profile, State.NewDraft(), run))
        local saved = assert(State.Load())
        assert(#saved.run.logs == 151 and saved.run.logs[151].text == "entry-1")
        assert(saved.profile.unlockedRelicIds.plan)
        print("T01_ENGINE_FILE_PASS " .. tostring(saved.saveRevision))
    end)
    if not ok then print("T01_ENGINE_FILE_FAIL " .. tostring(message)) end
    engine:Exit()
end
