#!/usr/bin/env python3
"""Upload build/sfx/*.ogg to Roblox as Audio assets (Open Cloud) and write ids into src/shared/Sounds.lua.

Usage: python3 tools/upload_sounds.py [--group GROUP_ID] [--only Name1,Name2]
API key: ~/.config/lockride/roblox_api_key (needs Assets read+write for the group).
Already uploaded ids are kept (build/sfx/ids.json) unless the file changed.
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys
import time
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / "build" / "sfx"
SOUNDS_LUA = ROOT / "src" / "shared" / "Sounds.lua"
IDS = SFX / "ids.json"
KEY = pathlib.Path.home() / ".config" / "lockride" / "roblox_api_key"
API = "https://apis.roblox.com/assets/v1"


def request(method, url, key, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read() or b"{}")


def upload(path, group, key):
    meta = {
        "assetType": "Audio",
        "displayName": f"GlitchRNG_{path.stem}",
        "description": "Glitch RNG sound",
        "creationContext": {"creator": {"groupId": str(group)}},
    }
    b = uuid.uuid4().hex
    parts = [
        f"--{b}\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n".encode()
        + json.dumps(meta).encode() + b"\r\n",
        f"--{b}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{path.name}\"\r\nContent-Type: audio/ogg\r\n\r\n".encode()
        + path.read_bytes() + b"\r\n",
        f"--{b}--\r\n".encode(),
    ]
    op = request("POST", f"{API}/assets", key, b"".join(parts), {"Content-Type": f"multipart/form-data; boundary={b}"})
    name = op.get("path") or f"operations/{op.get('operationId')}"
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", f"{API}/{name}", key)
    resp = op.get("response") or {}
    if not resp.get("assetId"):
        raise RuntimeError(f"upload failed for {path.name}: {op}")
    return resp["assetId"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", default="34355563")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    key = KEY.read_text().strip()
    ids = json.loads(IDS.read_text()) if IDS.exists() else {}
    only = set(filter(None, a.only.split(",")))
    for f in sorted(SFX.glob("*.ogg")):
        if only and f.stem not in only:
            continue
        digest = hashlib.sha1(f.read_bytes()).hexdigest()
        if ids.get(f.stem, {}).get("sha") == digest:
            continue
        try:
            asset = upload(f, a.group, key)
        except Exception as e:  # keep going, report at the end
            print("FAIL", f.stem, e, file=sys.stderr)
            continue
        ids[f.stem] = {"id": str(asset), "sha": digest}
        IDS.write_text(json.dumps(ids, indent=1))
        print("ok", f.stem, asset)
    src = SOUNDS_LUA.read_text()
    for name, v in ids.items():
        src = re.sub(rf'(\n\t{re.escape(name)} = )"[^"]*"', rf'\1"{v["id"]}"', src)
    SOUNDS_LUA.write_text(src)
    print("Sounds.lua updated")


if __name__ == "__main__":
    main()
