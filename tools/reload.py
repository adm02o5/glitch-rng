#!/usr/bin/env python3
"""Push Luau sources from src/ into the open Studio place (sets Script.Source; creates missing modules).

    python3 tools/reload.py [file ...]   # default: every .lua under src/
Run while Studio is in edit mode (not playing).
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MOUNTS = {
    "src/shared": "game.ReplicatedStorage.Shared",
    "src/server": "game.ServerScriptService.Server",
    "src/client": "game.StarterPlayer.StarterPlayerScripts.Client",
}


def target(path: pathlib.Path):
    rel = path.relative_to(ROOT).as_posix()
    for mount, inst in MOUNTS.items():
        if rel.startswith(mount + "/"):
            parts = rel[len(mount) + 1:].split("/")
            name = parts[-1]
            cls = "ModuleScript"
            for suf, c in ((".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")):
                if name.endswith(suf):
                    name, cls = name[: -len(suf)], c
                    break
            if name == "init":
                return inst, parts[:-1], cls, True
            return inst, parts[:-1] + [name], cls, False
    return None


def lua_str(s: str) -> str:
    eq = "=" * 8
    while f"]{eq}]" in s:
        eq += "="
    return f"[{eq}[{s}]{eq}]"


files = [pathlib.Path(f).resolve() for f in sys.argv[1:]] or sorted((ROOT / "src").rglob("*.lua"))
for f in files:
    t = target(f)
    if not t:
        continue
    root, parts, cls, is_init = t
    code = f"""
local node = {root}
local parts = {{{", ".join(json.dumps(p) for p in parts)}}}
for i, n in parts do
	local c = node:FindFirstChild(n)
	if not c then
		c = Instance.new(i == #parts and "{cls}" or "Folder")
		c.Name = n
		c.Parent = node
	end
	node = c
end
node.Source = {lua_str(f.read_text())}
print("ok {f.relative_to(ROOT).as_posix()}")
"""
    out = subprocess.run([sys.executable, str(ROOT / "tools" / "studio.py"), "call", "run_code", json.dumps({"command": code})],
                         capture_output=True, text=True, timeout=120)
    print(out.stdout.strip() or out.stderr.strip()[-500:])
