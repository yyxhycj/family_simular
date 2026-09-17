"""Load production Lua modules, using only the existing UI/File engine boundaries."""
import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/t01"))
from run import runtime, plain

parser = argparse.ArgumentParser()
parser.add_argument("--out", type=Path, required=True)
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=False)
results = []
for name in ("model", "economy", "ui", "integration"):
    directory = args.out / "storage" / name
    directory.mkdir(parents=True)
    try:
        lua, _ = runtime(directory)
        case = lua.execute((ROOT / "tests/opening" / (name + ".lua")).read_text())
        # Lua tables are callable to Python even without a __call metamethod.
        from lupa.lua54 import lua_type
        fn = case.run if lua_type(case) == "table" else case
        evidence = plain(fn())
        result = dict(id=name, status="PASS", evidence=evidence)
        if lua_type(case) == "table" and case.restart is not None:
            lua, _ = runtime(directory)
            case = lua.execute((ROOT / "tests/opening" / (name + ".lua")).read_text())
            result["restart"] = plain(case.restart())
        results.append(result)
    except Exception as error:
        results.append(dict(id=name, status="FAIL", error=repr(error)))
    print(name, results[-1]["status"])

paths = [*sorted((ROOT / "scripts/Jiaye").glob("*.lua")), *sorted((ROOT / "tests/opening").glob("*.*")),
         ROOT / "tests/t01/boundary.lua", ROOT / "tests/t01/run.py"]
manifest = dict(captured_at=datetime.now(timezone.utc).isoformat(),
    base_sha=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    layer="production Lua 5.4 modules; declaration-only UI, disk File adapter, separate Lua VM restart",
    engine=False, real_device=False,
    sources={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()},
    passed=sum(r["status"] == "PASS" for r in results), failed=sum(r["status"] == "FAIL" for r in results))
for name, value in (("results.json", results), ("manifest.json", manifest)):
    (args.out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
print(f'TOTAL {len(results)} | PASS {manifest["passed"]} | FAIL {manifest["failed"]}')
raise SystemExit(bool(manifest["failed"]))
