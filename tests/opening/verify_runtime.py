#!/usr/bin/env python3
"""Extract real OPENING_QA runtime evidence without treating readiness logs as events."""

import hashlib
import json
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    ROOT / "qa/opening/chrome/03-runtime.jsonl",
    ROOT / "qa/opening/chrome/04-runtime-restart.jsonl",
]
OUT = ROOT / "qa/opening/chrome/verification.json"
MARKER = "OPENING_QA {"


def frozen(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def extract(path):
    events = []
    if not path.exists():
        return events
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        try:
            record = json.loads(line)
            message = record.get("msg", "")
            start = message.find(MARKER)
            if start < 0:
                continue
            event, _ = json.JSONDecoder().raw_decode(message[start + len("OPENING_QA "):])
        except (json.JSONDecodeError, TypeError):
            continue
        events.append({"event": event, "source": f"{path.relative_to(ROOT)}:{line_no}", "t": record.get("t")})
    return events


def compact(event):
    draft = event.get("draft", {})
    run = event.get("run", {})
    saved_run = event.get("saved", {}).get("run", {})
    return {
        "screen": event.get("screen"), "view": event.get("view"), "page": event.get("page"),
        "frame": event.get("frame"), "points": event.get("points"),
        "draft": {key: draft.get(key) for key in ("rngSeed", "family", "placeId", "money", "grain", "workshop", "worldId")},
        "members": [{"id": m.get("id"), "name": m.get("name"), "nameSource": m.get("nameSource")} for m in draft.get("members", [])],
        "run": {key: run.get(key) for key in ("yearIndex", "money", "grain", "rngState")},
        "savedRun": {key: saved_run.get(key) for key in ("yearIndex", "money", "grain", "rngState")},
    }


def same_without_names(before, after):
    before = json.loads(json.dumps(before, ensure_ascii=False))
    after = json.loads(json.dumps(after, ensure_ascii=False))
    before.pop("family", None)
    after.pop("family", None)
    for draft in (before, after):
        for member in draft.get("members", []):
            member.pop("name", None)
    return frozen(before) == frozen(after)


def assertion(name, event_ids, observed, detail):
    return {"name": name, "status": "observed" if observed else "mismatch", "events": event_ids, "detail": detail}


def production_preview(saved):
    """Use the production Economy.Preview through the repository's Lua 5.4 harness."""
    sys.path.insert(0, str(ROOT / "tests/t01"))
    from run import plain, runtime
    with tempfile.TemporaryDirectory(prefix="opening-preview-") as directory:
        lua, _ = runtime(Path(directory))
        economy = lua.eval('require("Jiaye.Economy")')
        state = lua.eval('require("Jiaye.State")')
        if isinstance(economy, tuple):
            economy = economy[0]
        if isinstance(state, tuple):
            state = state[0]
        run, issues = state.NewRun(lua.table_from(saved["draft"], recursive=True), lua.table_from(saved["profile"], recursive=True))
        if run is None:
            raise RuntimeError(f"State.NewRun rejected logged draft: {plain(issues)}")
        return plain(economy.Preview(run))


def main():
    all_events = [item for source in SOURCES for item in extract(source)]
    grouped = {}
    for item in all_events:
        digest = hashlib.sha256(frozen(item["event"]).encode()).hexdigest()
        grouped.setdefault(digest, {"event": item["event"], "t": item["t"], "sources": []})["sources"].append(item["source"])
    # 03/04 are fixed captures. Do not use the live runtime watcher as evidence input.
    primary = extract(SOURCES[0])
    restart_events = extract(SOURCES[1])
    canonical = primary + [item for item in restart_events if item["t"] not in {entry["t"] for entry in primary}]
    def selected(t, line_no=None):
        candidates = [item for item in canonical if item["t"] == t and
                      (line_no is None or item["source"] == f"qa/opening/chrome/03-runtime.jsonl:{line_no}")]
        if len(candidates) != 1:
            raise RuntimeError(f"ambiguous or missing captured event t={t}, line={line_no}: {len(candidates)}")
        return candidates[0]
    def event(t, line_no=None): return selected(t, line_no)["event"]
    def eid(t, line_no=None): return selected(t, line_no)["source"]

    checks = []
    start = event(1789615781)
    saved = start["saved"]
    snapshot_ok = (frozen(start["draft"]) == frozen(start["run"]["openingSnapshot"]) ==
                   frozen(saved["draft"]) == frozen(saved["run"]["openingSnapshot"]))
    start_state_ok = all(start["run"][key] == saved["run"][key] for key in ("yearIndex", "money", "grain", "rngState"))
    checks.append(assertion("开局草案、运行快照和隔离存档一致", [eid(1789615781)], snapshot_ok and start_state_ok,
        {"run": compact(start)["run"], "savedRun": compact(start)["savedRun"]}))

    read_only = all(frozen(event(t)["draft"]) == frozen(event(1789615724)["draft"]) for t in (1789615770, 1789615780))
    checks.append(assertion("预览和计分视图不改草案", [eid(t) for t in (1789615724, 1789615770, 1789615780)], read_only,
        {"points": [event(t)["points"] for t in (1789615724, 1789615770, 1789615780)]}))

    same_360_390 = frozen(event(1789615988)["draft"]) == frozen(event(1789616029)["draft"])
    checks.append(assertion("同一 seed 的 360 和 390 逻辑草案一致", [eid(1789615988), eid(1789616029)], same_360_390,
        {"frames": [event(1789615988)["frame"], event(1789616029)["frame"]]}))

    checks.append({"name": "430 尺寸为独立 seed722 场景", "status": "observed_difference", "events": [eid(1789616029), eid(1789616048)],
        "detail": {"390RngSeed": event(1789616029)["draft"]["rngSeed"], "430RngSeed": event(1789616048)["draft"]["rngSeed"], "reason": "验收操作切换 seed；不能作为跨尺寸草案差异"}})

    rename_ok = same_without_names(event(1789616296, 16)["draft"], event(1789616305)["draft"])
    checks.append(assertion("改家族名只改变姓名字段，不改数值和成员关系", [eid(1789616296, 16), eid(1789616305)], rename_ok,
        {"family": [event(1789616296, 16)["draft"]["family"], event(1789616305)["draft"]["family"]], "points": [98, 98]}))

    cancel_ok = frozen(event(1789616387)["draft"]) == frozen(event(1789616413)["draft"])
    checks.append(assertion("超分 workshop 取消后恢复原草案", [eid(t) for t in (1789616387, 1789616412, 1789616413)], cancel_ok,
        {"points": [event(t)["points"] for t in (1789616387, 1789616412, 1789616413)]}))

    old_saved = event(1789616413)["saved"]
    over = event(1789616415)
    overbudget_ok = over["points"] == 102 and over["draft"]["money"] == 130 and frozen(over["saved"]) == frozen(old_saved)
    checks.append(assertion("超分草案未改已存局", [eid(1789616413), eid(1789616415)], overbudget_ok,
        {"candidate": {"points": over["points"], "money": over["draft"]["money"]}, "savedRun": compact(over)["savedRun"]}))

    loaded = event(1789616422)
    load_ok = frozen(loaded["draft"]) == frozen(old_saved["draft"]) and frozen(loaded["run"]) == frozen(old_saved["run"])
    checks.append(assertion("隔离读取恢复已存开局", [eid(1789616415), eid(1789616422)], load_ok, compact(loaded)))

    advanced = event(1789616435)
    year_ok = (advanced["run"]["yearIndex"], advanced["run"]["money"], advanced["run"]["grain"]) == (1, 65, 8)
    saved_year_ok = all(advanced["run"][key] == advanced["saved"]["run"][key] for key in ("yearIndex", "money", "grain", "rngState"))
    checks.append(assertion("首年结算写回运行态和存档", [eid(1789616422), eid(1789616435)], year_ok and saved_year_ok,
        {"before": compact(loaded)["run"], "after": compact(advanced)["run"], "lastLedger": advanced["run"].get("lastLedger")}))

    preview = production_preview(loaded["saved"])
    preview_ok = frozen(preview) == frozen(advanced["run"].get("lastLedger"))
    checks.append(assertion("首年真实账本与生产 Economy.Preview 一致", [eid(1789616422), eid(1789616435)], preview_ok,
        {"preview": preview, "actualLastLedger": advanced["run"].get("lastLedger")}))

    restarted = event(1789616507)
    restart_ok = all(restarted["run"][key] == advanced["run"][key] for key in ("yearIndex", "money", "grain", "rngState"))
    checks.append(assertion("重载引擎后隔离读取恢复首年结算状态", [eid(1789616435), eid(1789616507)], restart_ok,
        {"beforeRestart": compact(advanced)["run"], "afterRestart": compact(restarted)["run"]}))

    result = {
        "evidenceLayer": "真实引擎 runtime 日志；只提取外层 JSON msg 中精确包含 OPENING_QA { 的事件",
        "sources": [{"path": str(path.relative_to(ROOT)), "openingQaEvents": len(extract(path))} for path in SOURCES],
        "events": [{"id": item["source"], "t": item["t"], "summary": compact(item["event"]),
                    "alsoPresentInRestartCapture": len(grouped[hashlib.sha256(frozen(item["event"]).encode()).hexdigest()]["sources"]) > 1} for item in canonical],
        "assertions": checks,
        "pending": [],
    }
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
