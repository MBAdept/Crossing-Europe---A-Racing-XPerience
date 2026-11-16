#!/usr/bin/env bash
# AS2R: export (cached) + bake + manifest + validate for a glob of models.
# usage: rebuild.sh "<glob>" [--force] [--novalidate]
# One heavy job at a time, nice 19, one worker (early start of M2: the M1 assembly has priority).
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
export XDG_DATA_HOME=$S/xdg
mkdir -p "$S/logs" "$XDG_DATA_HOME"
cd "$WT"
GLOB="${1:-*}"
shift || true
VAL=1
ARGS=()
for a in "$@"; do
	if [ "$a" = "--novalidate" ]; then VAL=0; else ARGS+=("$a"); fi
done
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$GLOB" --jobs=1 "${ARGS[@]}" > "$S/logs/export.log" 2>&1
echo "export exit $?"
grep -E "EXPORT|Error|FEHLER|Traceback|raise |File \"|Exception" "$S/logs/export.log" | tail -40
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$GLOB" > "$S/logs/bake.log" 2>&1
echo "bake exit $?"
grep -vE "^\s*$|Godot Engine|OpenGL" "$S/logs/bake.log" | tail -12
python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -2
if [ "$VAL" = "1" ]; then
	nice -n 19 python3 tools/blender/validate_models.py --report > "$S/logs/validate.log" 2>&1
	echo "validate exit $?"
	grep -E "FEHLER|Fehler|CHECK|ERROR|über|zu " "$S/logs/validate.log" | tail -30
fi
