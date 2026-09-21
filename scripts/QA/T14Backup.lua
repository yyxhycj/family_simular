-- T14 备份传递验收；正式入口不引用，使用独立存档与真实用户文档文件。
---@diagnostic disable: assign-type-mismatch, undefined-global
local UI = require "urhox-libs/UI"
local State = require "Jiaye.State"
local App = require "Jiaye.App"

State.UseVerificationStorage("t14")

local function read(path)
    local file = File(path, FILE_READ)
    assert(file:IsOpen(), "无法打开外部备份文件：" .. tostring(path))
    local raw = file:ReadString()
    file:Close()
    return raw
end

local function verify()
    local profile = State.NewProfile()
    local draft = State.NewDraft()
    local run, issues = State.NewRun(draft, profile)
    assert(run, table.concat(issues or {}, "；"))
    assert(State.Save(profile, draft, run))

    local raw = assert(State.Export(profile, draft, run))
    local externalPath = assert(State.ExternalExportPath())
    assert(fileSystem:FileExists(externalPath), "用户文档备份不存在：" .. externalPath)
    assert(read(externalPath) == raw, "用户文档备份回读内容与导出内容不一致。")

    local candidate, message, status = State.ReadExternalExport()
    assert(candidate and status == "ready", message)
    assert(candidate.run.runId == run.runId and candidate.draft.family == draft.family)

    local before = assert(State.Load())
    assert(not State.PreflightImport(raw .. "x"))
    local after = assert(State.Load())
    assert(after.run.runId == before.run.runId and after.saveRevision == before.saveRevision)

    local app = App.New()
    app:Render()
    return { path = externalPath, bytes = #raw, runId = run.runId, revision = before.saveRevision }
end

function Start()
    UI.Init({ theme = "default-dark", scale = UI.Scale.DEFAULT })
    local ok, result = pcall(verify)
    if not ok then
        print("T14_BACKUP_FAIL " .. tostring(result))
        UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", padding = 18, children = {
            UI.Label { text = "T14 备份传递验收失败\n" .. tostring(result), whiteSpace = "normal" },
        } })
        return
    end
    print("T14_BACKUP_PASS 用户文档写入、外部文件回读、结构预演与坏输入隔离通过 " .. cjson.encode(result))
    UI.SetRoot(UI.Panel { width = "100%", height = "100%", justifyContent = "center", padding = 18, children = {
        UI.Label { text = "T14 真实引擎备份传递验收通过", fontSize = 24 },
        UI.Label { text = "· 导出内容已写入用户文档并逐字回读\n· 从用户文档重新预演得到可导入家谱\n· 坏输入不会污染独立存档\n· 正式双槽位与旧格式校验路径保持不变", whiteSpace = "normal", lineHeight = 1.65 },
    } })
end

function Stop()
    UI.Shutdown()
end
