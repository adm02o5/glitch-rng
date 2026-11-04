#!/usr/bin/env python3
"""Мини-клиент к Roblox Studio MCP (rbx-studio-mcp): запускать код в открытом Studio и играть.

    python3 tools/studio.py list
    python3 tools/studio.py call <tool> '<json-аргументы>' [имя_аргумента файл]
Последние два параметра подставляют содержимое файла в аргумент (удобно для run_code).
"""
import json
import subprocess
import sys

proc = subprocess.Popen(["/home/adm02o5/.local/bin/rbx-studio-mcp", "--stdio"],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
rid = 0


def send(method, params=None, notify=False):
    global rid
    msg = {"jsonrpc": "2.0", "method": method}
    if params is not None:
        msg["params"] = params
    if not notify:
        rid += 1
        msg["id"] = rid
    proc.stdin.write(json.dumps(msg) + "\n")
    proc.stdin.flush()
    if notify:
        return None
    while True:
        line = proc.stdout.readline()
        if not line:
            print("EOF; stderr:", proc.stderr.read()[-2000:])
            sys.exit(1)
        data = json.loads(line)
        if data.get("id") == rid:
            return data


send("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "lr", "version": "1"}})
send("notifications/initialized", notify=True)
if sys.argv[1] == "list":
    for t in send("tools/list", {})["result"]["tools"]:
        print("==", t["name"], ":", t.get("description", "")[:300])
else:
    args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
    if len(sys.argv) > 5:
        args[sys.argv[4]] = open(sys.argv[5], encoding="utf-8").read()
    res = send("tools/call", {"name": sys.argv[2], "arguments": args})
    if "result" in res:
        for c in res["result"].get("content", []):
            print(c.get("text", c))
    else:
        print(json.dumps(res, ensure_ascii=False)[:4000])
proc.terminate()
