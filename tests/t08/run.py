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
        natural_storage = args.out / "natural-storage"
        natural_storage.mkdir()
        lua, _ = runtime(natural_storage)
        case = lua.execute((ROOT / "tests/t08/contract.lua").read_text())
        natural = {"id": "t08_natural_restart", "status": "PASS", "evidence": plain(case.saveNatural())}
        lua, _ = runtime(natural_storage)
        case = lua.execute((ROOT / "tests/t08/contract.lua").read_text())
        natural["restart"] = plain(case.naturalRestart())

        storage = args.out / "collapse-storage"
        storage.mkdir()
        lua, _ = runtime(storage)
        case = lua.execute((ROOT / "tests/t08/contract.lua").read_text())
        result = {"id": "t08_contract", "status": "PASS", "evidence": plain(case.run())}
        lua, _ = runtime(storage)
        case = lua.execute((ROOT / "tests/t08/contract.lua").read_text())
        result["restart"] = plain(case.restart())
    except Exception as error:
        natural = {"id": "t08_natural_restart", "status": "FAIL", "error": repr(error)}
        result = {"id": "t08_contract", "status": "FAIL", "error": repr(error)}
    print(natural["id"], natural["status"])
    print(result["id"], result["status"])
    paths = [
        *sorted((ROOT / "scripts/Jiaye").glob("*.lua")),
        ROOT / "tests/t01/boundary.lua", ROOT / "tests/t01/run.py",
        ROOT / "tests/t08/contract.lua", ROOT / "tests/t08/run.py",
    ]
    manifest = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "base_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "lupa": lupa.__version__, "lua": "Lua 5.4",
        "layer": "production Lua modules; declaration-only UI, disk File adapter; separate Lua VM restart",
        "engine": False, "real_device": False,
        "sources": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
        "passed": int(natural["status"] == "PASS") + int(result["status"] == "PASS"),
        "failed": int(natural["status"] != "PASS") + int(result["status"] != "PASS"),
    }
    for name, value in (("results.json", [natural, result]), ("manifest.json", manifest)):
        (args.out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    raise SystemExit(manifest["failed"])


if __name__ == "__main__":
    main()
