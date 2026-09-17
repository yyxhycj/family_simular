"""Run the focused T06 family-life and history contract against production Lua modules."""
import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import lupa

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/t01"))
from run import plain, runtime


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    try:
        storage = args.out / "storage"
        storage.mkdir()
        lua, _ = runtime(storage)
        case = lua.execute((ROOT / "tests/t06/contract.lua").read_text())
        result = {"id": "t06_contract", "status": "PASS", "evidence": plain(case.run())}
        lua, _ = runtime(storage)
        case = lua.execute((ROOT / "tests/t06/contract.lua").read_text())
        result["restart"] = plain(case.restart())
    except Exception as error:
        result = {"id": "t06_contract", "status": "FAIL", "error": repr(error)}
    print(result["id"], result["status"])
    paths = [
        *sorted((ROOT / "scripts/Jiaye").glob("*.lua")),
        ROOT / "tests/t01/boundary.lua", ROOT / "tests/t01/run.py",
        ROOT / "tests/t06/contract.lua", ROOT / "tests/t06/run.py",
    ]
    manifest = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "base_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "lupa": lupa.__version__, "lua": "Lua 5.4",
        "layer": "production Lua modules; declaration-only UI, disk File adapter; separate Lua VM restart",
        "engine": False, "real_device": False,
        "sources": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
        "passed": int(result["status"] == "PASS"), "failed": int(result["status"] != "PASS"),
    }
    for name, value in (("results.json", [result]), ("manifest.json", manifest)):
        (args.out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    raise SystemExit(manifest["failed"])


if __name__ == "__main__":
    main()
