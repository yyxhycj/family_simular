local State = require "Jiaye.State"

local Habits = {}

local function IsV12(run)
    return type(run) == "table" and run.relicRulesVersion == "1.2"
end

local function Ensure(run)
    run.habitProgress = run.habitProgress or {}
    run.habitFormations = run.habitFormations or {}
    run.habitProgress.education = run.habitProgress.education or 0
    run.habitProgress.educationMissed = run.habitProgress.educationMissed or 0
end

local function ReaderIds(ledger)
    local ids = {}
    for _, row in ipairs(type(ledger) == "table" and ledger.members or {}) do
        if row.executed == true and row.jobId == "study" then table.insert(ids, row.memberId) end
    end
    return ids
end

local function AddFact(run, text, memberIds, detail)
    detail = detail or {}
    detail.source = "Habits.Advance"
    detail.habitId = "education"
    detail.runYear = run.yearIndex
    return State.AddFact(run, "habit", text, memberIds, detail)
end

function Habits.Growth(run, member)
    if not IsV12(run) or not member or member.alive == false or member.jobId ~= "study" then return 0 end
    local record = type(run.habitFormations) == "table" and run.habitFormations.education
    if not record then return 0 end
    if record.status == "active" or record.status == "paused" then return 1 end
    return 0
end

function Habits.Advance(run, ledger)
    if not IsV12(run) then return nil, "旧局保留原有家风逻辑。" end
    Ensure(run)
    if run.habitProgress.educationLastYear == run.yearIndex then return run.habitFormations.education end
    run.habitProgress.educationLastYear = run.yearIndex
    local readers = ReaderIds(ledger)
    local hasReader = #readers > 0
    local record = run.habitFormations.education

    if not record then
        run.habitProgress.education = hasReader and run.habitProgress.education + 1 or 0
        run.habitProgress.educationMissed = 0
        if run.habitProgress.education >= 3 then
            record = { habitId = "education", name = "不废灯火", status = "active", effect = "learn+1", formedYear = run.yearIndex, source = "Habits.Advance" }
            run.habitFormations.education = record
            AddFact(run, "连续三年有人实际读书，形成家风“不废灯火”；下一年度起合格读书人学识 +1。", readers, {
                status = record.status, effect = record.effect, validReaders = State.Copy(readers),
            })
        end
        return record
    end

    if record.status == "inactive" then
        if hasReader then
            run.habitProgress.education = run.habitProgress.education + 1
            if run.habitProgress.education >= 2 then
                record.status = "active"
                record.reformedYear = run.yearIndex
                run.habitProgress.education = 0
                run.habitProgress.educationMissed = 0
                AddFact(run, "连续两年有人实际读书，家风“不废灯火”重新点亮；下一年度起合格读书人学识 +1。", readers, {
                    status = record.status, effect = record.effect, validReaders = State.Copy(readers),
                })
            end
        else
            run.habitProgress.education = 0
        end
        return record
    end

    if hasReader then
        if record.status == "paused" then
            record.status = "active"
            record.recoveredYear = run.yearIndex
            AddFact(run, "家中恢复实际读书，家风“不废灯火”当年重新生效。", readers, {
                status = record.status, effect = record.effect, validReaders = State.Copy(readers),
            })
        end
        run.habitProgress.educationMissed = 0
    else
        run.habitProgress.educationMissed = run.habitProgress.educationMissed + 1
        if run.habitProgress.educationMissed == 1 then
            record.status = "paused"
            AddFact(run, "本年度无人实际完成读书，家风“不废灯火”暂歇；恢复读书即可继续生效。", {}, {
                status = record.status, effect = record.effect,
            })
        else
            record.status = "inactive"
            run.habitProgress.education = 0
            AddFact(run, "连续两年无人实际完成读书，家风“不废灯火”暂时失效；重新连续读书两年后恢复。", {}, {
                status = record.status, effect = record.effect,
            })
        end
    end
    return record
end

return Habits
