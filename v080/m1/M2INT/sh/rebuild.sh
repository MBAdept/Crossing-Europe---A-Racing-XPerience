#!/usr/bin/env bash
# M2INT: export (cached unless --force) + bake + manifest + validate for a glob of models.
# usage: rebuild.sh "<glob>" [--force] [--novalidate] [--nobake]
# Niceness: 19 until the lead's ZS1_FERTIG exists, then 10. One worker.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
NICE=19
[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
export XDG_DATA_HOME=$S/xdg
export CE_THREADS=${CE_THREADS:-2}
mkdir -p "$S/logs" "$XDG_DATA_HOME"
cd "$WT"
GLOB="${1:-*}"
shift || true
VAL=1
BAKE=1
ARGS=()
for a in "$@"; do
	case "$a" in
		--novalidate) VAL=0 ;;
		--nobake) BAKE=0 ;;
		*) ARGS+=("$a") ;;
	esac
done
TAG=$(echo "$GLOB" | tr '/*,' '___')
t0=$(date +%s)
nice -n $NICE /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$GLOB" --jobs=1 "${ARGS[@]}" > "$S/logs/export_$TAG.log" 2>&1
echo "export exit $? ($(( $(date +%s) - t0 )) s)"
grep -E "EXPORT|Error|FEHLER|Traceback|raise |File \"|Exception" "$S/logs/export_$TAG.log" | tail -60
if [ "$BAKE" = "1" ]; then
	nice -n $NICE godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$GLOB" > "$S/logs/bake_$TAG.log" 2>&1
	echo "bake exit $?"
	grep -vE "^\s*$|Godot Engine|OpenGL" "$S/logs/bake_$TAG.log" | tail -8
	python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -2
fi
if [ "$VAL" = "1" ]; then
	nice -n $NICE python3 tools/blender/validate_models.py --report > "$S/logs/validate.log" 2>&1
	echo "validate exit $?"
	grep -E "FEHLER|Fehler|CHECK|ERROR" "$S/logs/validate.log" | tail -30
fi
