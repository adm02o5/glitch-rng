#!/usr/bin/env bash
# Build Glitch RNG aura animations in headless Blender.
#   tools/blender/anim/run.sh NeonPulse [Glitch ...]     run auras/<Id>.py (check, .blend, .lua, preview)
#   tools/blender/anim/run.sh --all                      every auras/*.py
#   tools/blender/anim/run.sh --blend art/anims/X.blend  re-export a .blend edited by hand
set -euo pipefail
cd "$(dirname "$0")/../../.."
BLENDER="${BLENDER:-$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Blender/blender}"
[ -x "$BLENDER" ] || BLENDER="$(command -v blender)"
run() { "$BLENDER" -b --factory-startup --python-exit-code 1 -P "$@" 2>&1 | grep -E "^\[|Error|Traceback|File \"|^  |assert" | grep -v "^  *$" || true; }
if [ "${1:-}" = "--blend" ]; then
	run tools/blender/anim/lib.py -- --blend "$2"
	exit
fi
ids=("$@")
if [ "${1:-}" = "--all" ]; then
	ids=()
	for f in tools/blender/anim/auras/*.py; do ids+=("$(basename "$f" .py)"); done
fi
for id in "${ids[@]}"; do
	echo "=== $id"
	run "tools/blender/anim/auras/$id.py"
done
