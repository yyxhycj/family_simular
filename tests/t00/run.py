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
HISTORICAL = "546ff6cf7e4225632fe9871ba70188e6aa730e82"
HANDOFF = ROOT / "jiaye-review-design-handoff"
parser = argparse.ArgumentParser()
parser.add_argument("--out", type=Path, required=True, help="New evidence directory; existing files are never overwritten")
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=False)
lua = LuaRuntime(unpack_returned_tuples=True)


def plain(value):
    if lua_type(value) != "table":
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [plain(value[i]) for i in range(1, len(keys) + 1)]
    return {key: plain(value[key]) for key in keys}


def encode(value):
    # Empty Lua tables encode as {}, as in the default lua-cjson convention.
    return json.dumps(plain(value), ensure_ascii=False, sort_keys=True, allow_nan=False)


def decode(raw):
    return lua.table_from(json.loads(raw), recursive=True)


lua.globals().cjson = lua.table(encode=encode, decode=decode)
lua.globals().package.path = str(ROOT / "scripts/?.lua") + ";" + lua.globals().package.path
bundle = plain(lua.execute((ROOT / "tests/t00/audit.lua").read_text()))


def write(name, value):
    (args.out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


source_paths = [ROOT / "scripts/main.lua", *sorted((ROOT / "scripts/Jiaye").glob("*.lua"))]
source_records = {}
for path in source_paths:
    relative = str(path.relative_to(ROOT))
    historical = subprocess.run(
        ["git", "show", f"{HISTORICAL}:{relative}"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False
    )
    old = historical.stdout if historical.returncode == 0 else None
    current = path.read_bytes()
    source_records[relative] = {
        "sha256": hashlib.sha256(current).hexdigest(),
        "historical_present": old is not None,
        "historical_sha256": hashlib.sha256(old).hexdigest() if old is not None else None,
        "identical_to_historical": old is not None and current == old,
    }
reference_hashes = {
    str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
    for path in sorted(HANDOFF.rglob("*")) if path.is_file() and path.name != ".DS_Store"
}
baseline = json.loads((HANDOFF / "baseline/v5/data/v5-config.snapshot.json").read_text())
write("v5-default.json", {"source": "jiaye-review-design-handoff/baseline/v5/data/v5-config.snapshot.json",
                          "layer": "frozen supplied V5 snapshot, not newly executed HTML",
                          "draft": baseline["defaultDraft"], "pointGroups": baseline["pointGroups"]})
write("current-default.json", bundle["default"])
write("current-cases.json", bundle["fixtures"])
write("results.json", bundle["results"])
passed = sum(item["status"] == "PASS" for item in bundle["results"])
write("manifest.json", {
    "captured_at": datetime.now(timezone.utc).isoformat(),
    "target_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "historical_sha": HISTORICAL,
    "platform": platform.platform(), "python": platform.python_version(),
    "lupa": lupa.__version__, "lua": lua.eval("_VERSION"),
    "layer": "real Lua modules; UI declarations/toasts and File are adapters; cjson uses Python JSON",
    "no_engine_or_device_execution": True, "source_files": source_records,
    "reference_sha256": reference_hashes,
    "harness_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in sorted((ROOT / "tests/t00").glob("*")) if p.is_file()},
    "passed": passed, "failed": len(bundle["results"]) - passed,
})
for item in bundle["results"]:
    print(f'{item["id"]}\t{item["status"]}\t{item["title"]}')
print(f'TOTAL {len(bundle["results"])} | PASS {passed} | FAIL {len(bundle["results"]) - passed}')
raise SystemExit(0 if passed == len(bundle["results"]) else 1)
