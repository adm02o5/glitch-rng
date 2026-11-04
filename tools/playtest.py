#!/usr/bin/env python3
"""Прогон игры в открытом Studio с логами клиента.

    python3 tools/playtest.py [секунд] [server.lua] [client.lua]

Ставит в StarterPlayerScripts временный LocalScript ZZ_Relay: он пересылает на сервер весь Output
клиента и выполняет client.lua (если указан). Сервер печатает это с пометкой [CLIENT] и выполняет
server.lua. После прогона ZZ_Relay удаляется. Печатает уникальные строки лога.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 20
EXTRA = 75  # сколько server.lua может работать после паузы
server_code = Path(sys.argv[2]).read_text(encoding="utf-8") if len(sys.argv) > 2 and sys.argv[2] != "-" else ""
client_code = Path(sys.argv[3]).read_text(encoding="utf-8") if len(sys.argv) > 3 else ""

relay_source = """
local LogService = game:GetService("LogService")
local remote = game.ReplicatedStorage:WaitForChild("ZZ_ClientLog", 30)
local function send(msg) if remote then remote:FireServer(msg) end end
LogService.MessageOut:Connect(function(msg, kind)
	if kind ~= Enum.MessageType.MessageInfo then send(kind.Name .. ": " .. msg) end
end)
game:GetService("ScriptContext").Error:Connect(function(msg, trace) send("SCRIPTERROR: " .. msg .. " | " .. trace) end)
task.spawn(function()
""" + client_code + """
end)
"""


def studio(tool, args):
    out = subprocess.run([sys.executable, str(ROOT / "studio.py"), "call", tool, json.dumps(args)],
                         capture_output=True, text=True, timeout=seconds + EXTRA + 90)
    return out.stdout


install = ("local s = game.StarterPlayer.StarterPlayerScripts:FindFirstChild('ZZ_Relay') if s then s:Destroy() end "
           "local ls = Instance.new('LocalScript') ls.Name = 'ZZ_Relay' ls.Source = [=====[" + relay_source + "]=====]" +
           " ls.Parent = game.StarterPlayer.StarterPlayerScripts print('relay ok')")
print(studio("run_code", {"command": install}).strip())

server = """
local remote = Instance.new("RemoteEvent")
remote.Name = "ZZ_ClientLog"
remote.Parent = game.ReplicatedStorage
local function cut(t) -- обрезка по целым символам UTF-8 (иначе кириллица ломает JSON ответа Studio)
	t = tostring(t) if #t <= 700 then return t end
	return string.sub(t, 1, (utf8.offset(t, 0, 700) or 701) - 1)
end
remote.OnServerEvent:Connect(function(_, msg) print("[CLIENT] " .. cut(msg)) end)
task.wait(%d)
%s
return "done"
""" % (seconds, server_code)
raw = studio("run_script_in_play_mode", {"mode": "start_play", "timeout": seconds + EXTRA, "code": server})
print(studio("run_code", {"command": "local s = game.StarterPlayer.StarterPlayerScripts:FindFirstChild('ZZ_Relay') if s then s:Destroy() end print('relay removed')"}).strip())
try:
    data = json.loads(raw[raw.index("{"):])
except ValueError:
    print(raw[:3000])
    sys.exit(1)
seen = set()
skip = ("Stack Begin", "Stack End", "cloud_", "Reference is set", "Attempt to connect failed: Passed value is not a function",
        "UIBlox", "203785492")
for item in data.get("logs", []) + data.get("errors", []):
    msg = item["message"]
    if msg in seen or any(s in msg for s in skip):
        continue
    seen.add(msg)
    print(item["level"], msg[:900])
print("result:", data.get("value"), data.get("error"))
