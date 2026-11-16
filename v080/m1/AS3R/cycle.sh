#!/usr/bin/env bash
# AS3R scratch: export -> bake -> import -> manifest for one or more model globs (one worker, lowest priority).
#   cycle.sh "<glob>" ["<glob>" ...] [--force]
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
cd "$WT"
FORCE=""
GLOBS=()
for a in "$@"; do
	if [ "$a" = "--force" ]; then FORCE="--force"; else GLOBS+=("$a"); fi
done
t0=$(date +%s)
for g in "${GLOBS[@]}"; do
	echo "=== export $g $(date +%H:%M:%S)"
	nice -n 19 "$BPY" tools/blender/export_models.py --only="$g" --jobs=1 $FORCE 2>&1 | grep -E "^EXPORT|Error|Traceback|line [0-9]|FEHLER|Exception|RuntimeError|ValueError|IndexError|KeyError|TypeError|NameError|AttributeError" | head -40
done
t1=$(date +%s)
for g in "${GLOBS[@]}"; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" 2>&1 | grep -vE "^Godot|^\s*$|^AudioManager" | tail -6
done
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 "$BPY" tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "cycle: export $((t1 - t0)) s, gesamt $(( $(date +%s) - t0 )) s"
