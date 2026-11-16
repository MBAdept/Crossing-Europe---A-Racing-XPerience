#!/usr/bin/env bash
# AS1R: export (cached) + bake + manifest + validate for a glob of models.  usage: rebuild.sh "<glob>" [--force]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R
export XDG_DATA_HOME=$S/xdg
cd "$WT"
GLOB="${1:-*}"
shift || true
nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$GLOB" --jobs=2 "$@" > "$S/logs/export.log" 2>&1
grep -E "EXPORT|Export:|Error|FEHLER|Traceback|raise |File \"" "$S/logs/export.log" | tail -40
nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$GLOB" > "$S/logs/bake.log" 2>&1
grep -vE "^\s*$|Godot Engine|OpenGL" "$S/logs/bake.log" | tail -12
python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -2
python3 tools/blender/validate_models.py > "$S/logs/validate.log" 2>&1
tail -25 "$S/logs/validate.log"
