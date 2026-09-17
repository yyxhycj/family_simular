import argparse
import hashlib
import json
import platform
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import lupa
from lupa.lua54 import LuaRuntime, lua_type

ROOT = Path(__file__).resolve().parents[2]


def plain(value):
    if lua_type(value) != "table":
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [plain(value[index]) for index in range(1, len(keys) + 1)]
    return {key: plain(value[key]) for key in keys}


def runtime(directory):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().package.path = str(ROOT / "scripts/?.lua") + ";" + lua.globals().package.path
    lua.globals().cjson = lua.table(
        encode=lambda value: json.dumps(plain(value), ensure_ascii=False, sort_keys=True, allow_nan=False),
        decode=lambda raw: lua.table_from(json.loads(raw), recursive=True),
    )
    fault = lua.table(mode="")
    lua.globals().fault = fault

    def open_file(path, mode):
        try:
            return (directory / path).open("wb" if mode == 2 else "rb")
        except OSError:
            return None

    def write_file(handle, raw):
        if fault.mode == "write_false":
            handle.write(b"{")
            return False
        handle.write(raw.encode() + b"\0")
        return True

    lua.globals().disk_open = open_file
    lua.globals().disk_write = write_file
    lua.globals().disk_read = lambda handle: handle.read().split(b"\0", 1)[0].decode()
    lua.globals().disk_close = lambda handle: handle.close()
    lua.globals().disk_exists = lambda path: (directory / path).exists()
    lua.execute((ROOT / "tests/t10/boundary.lua").read_text())
    return lua, lua.execute((ROOT / "tests/t10/contract.lua").read_text())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True, help="New evidence directory")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    results = []
    for name in ("current_roundtrip", "v5_migration", "ended", "damaged", "write_failure"):
        storage = args.out / "storage" / name
        storage.mkdir(parents=True)
        try:
            lua, cases = runtime(storage)
            evidence = plain(cases[name]())
            lua, _ = runtime(storage)
            restart_checks = {
                "current_roundtrip": "local State = require 'Jiaye.State'; local value = assert(State.Load()); assert(#value.run.logs >= 151 and value.run.relicInstances[1].status == 'investigating'); return { revision = value.saveRevision, history = #value.run.logs, rng = value.run.rngState, dueYear = value.run.relicInstances[1].dueYear }",
                "v5_migration": "local State = require 'Jiaye.State'; local value = assert(State.Load()); assert(value.run.events[1].type == 'relic_resolution' and value.profile.unlockedRelicIds.plan); return { revision = value.saveRevision, run = value.run.runId, pending = value.run.events[1].type }",
                "ended": "local State = require 'Jiaye.State'; local value = assert(State.Load()); assert(value.run.ending.id == 'last' and #value.profile.endingRecords == 1); return { revision = value.saveRevision, ending = value.run.ending.id }",
                "damaged": "local State = require 'Jiaye.State'; local value = assert(State.Load()); return { revision = value.saveRevision, family = value.draft.family }",
                "write_failure": "local State = require 'Jiaye.State'; local value = assert(State.Load()); return { revision = value.saveRevision, family = value.draft.family }",
            }
            restart = plain(lua.execute(restart_checks[name]))
            results.append({"id": name, "status": "PASS", "evidence": evidence, "restart": restart})
        except Exception as error:
            results.append({"id": name, "status": "FAIL", "error": str(error)})
        print(name, results[-1]["status"])

    sources = [*sorted((ROOT / "scripts/Jiaye").glob("*.lua")), *sorted((ROOT / "tests/t10").glob("*"))]
    manifest = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "base_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "platform": platform.platform(),
        "lupa": lupa.__version__,
        "lua": "Lua 5.4",
        "layer": "production State and Simulation with disk-backed UrhoX File boundary; fresh VM restart",
        "engine": False,
        "real_device": False,
        "sources": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources if path.is_file()},
        "passed": sum(item["status"] == "PASS" for item in results),
        "failed": sum(item["status"] == "FAIL" for item in results),
    }
    (args.out / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n")
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"TOTAL {len(results)} | PASS {manifest['passed']} | FAIL {manifest['failed']}")
    raise SystemExit(bool(manifest["failed"]))


if __name__ == "__main__":
    main()
