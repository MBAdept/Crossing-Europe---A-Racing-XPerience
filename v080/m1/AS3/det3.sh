#!/usr/bin/env bash
# AS3 scratch: forced re-export of every AS3 model (one worker, nice 19), bake, import, manifest; afterwards
# `git status` shows what changed (empty = byte-identical to the committed files).
#   det3.sh <label>
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
t0=$(date +%s)
for g in "props/tree_*" "props/bush_*" "props/cover_*" "props/heather" "props/rock_*" "props/cliff"; do
	echo "=== export $g $(date +%H:%M:%S)"
	nice -n 19 "$BPY" tools/blender/export_models.py --only="$g" --force --jobs=1 2>&1 \
		| grep -E "^EXPORT|Error|Traceback|FEHLER|Exception" | head -40
done
t1=$(date +%s)
echo "Export: $((t1 - t0)) s"
for g in "props/tree_*" "props/bush_*" "props/cover_*" "props/heather" "props/rock_*" "props/cliff"; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" 2>&1 \
		| grep -vE "^Godot|^\s*$|^AudioManager" | tail -4
done
t2=$(date +%s)
echo "Bake: $((t2 - t1)) s"
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 "$BPY" tools/blender/export_models.py --manifest-only 2>&1 | tail -2
echo "=== git status (leer = byte-identisch) $1"
git status --porcelain
echo "=== Ende $1 $(date +%H:%M:%S)"
