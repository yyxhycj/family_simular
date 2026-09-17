"""T01: real Lua 5.4 modules, declaration-only UI and disk-backed UrhoX File adapter."""
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
        return [plain(value[i]) for i in range(1, len(keys) + 1)]
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
        if fault.mode == "open" and mode == 2:
            return None
        try:
            return (directory / path).open("wb" if mode == 2 else "rb")
        except OSError:
            return None

    def write_file(handle, raw):
        data = raw.encode() + b"\0"  # UrhoX WriteString uses a null terminator.
        if fault.mode == "exception":
            raise OSError("injected write exception")
        if fault.mode in ("partial", "zero", "corrupt"):
            handle.write(data[:5] if fault.mode == "partial" else b"{broken")
            return {"partial": False, "zero": 0, "corrupt": True}[fault.mode]
        handle.write(data)
        return True  # Engine signature is boolean, not a byte count.

    lua.globals().disk_open = open_file
    lua.globals().disk_write = write_file
    lua.globals().disk_read = lambda handle: handle.read().split(b"\0", 1)[0].decode()
    lua.globals().disk_close = lambda handle: handle.close()
    lua.globals().disk_exists = lambda path: (directory / path).exists()
    lua.globals().disk_raw = lambda path, raw: (directory / path).write_bytes(raw.encode() + b"\0")
    lua.execute((ROOT / "tests/t01/boundary.lua").read_text())
    return lua, lua.execute((ROOT / "tests/t01/cases.lua").read_text())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True, help="New evidence directory; never overwrite an earlier run")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    results = []
    for name in ("history", "succession", "collection", "failed_new_run", "failed_action", "recovery"):
        directory = args.out / "storage" / name
        directory.mkdir(parents=True)
        try:
            lua, cases = runtime(directory)
            evidence = plain(cases[name].run())
            # Recreate the whole VM: globals, modules, App and RNG all reload from disk.
            lua, cases = runtime(directory)
            restart = plain(cases[name].restart())
            results.append(dict(id=name, status="PASS", evidence=evidence, restart=restart))
        except Exception as error:
            results.append(dict(id=name, status="FAIL", error=str(error)))
        print(name, results[-1]["status"])

    paths = [*sorted((ROOT / "scripts/Jiaye").glob("*.lua")), *sorted((ROOT / "tests/t01").glob("*"))]
    manifest = dict(
        captured_at=datetime.now(timezone.utc).isoformat(),
        base_sha=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        platform=platform.platform(), lupa=lupa.__version__, lua="Lua 5.4",
        layer="actual Lua modules and UI callbacks; declaration-only UI; disk File adapter and Python JSON; new VM restart",
        engine=False, real_device=False,
        sources={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()},
        passed=sum(r["status"] == "PASS" for r in results), failed=sum(r["status"] == "FAIL" for r in results),
    )
    for name, value in (("results.json", results), ("manifest.json", manifest)):
        (args.out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    print(f'TOTAL {len(results)} | PASS {manifest["passed"]} | FAIL {manifest["failed"]}')
    raise SystemExit(bool(manifest["failed"]))


if __name__ == "__main__":
    main()
