#!/usr/bin/env bash
# export + bake + manifest helper: ex.sh <glob> [--force]
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1
export XDG_DATA_HOME=$S/xdg
mkdir -p "$XDG_DATA_HOME"
GLOB="$1"; shift
cd "$W"
nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$GLOB" --jobs=${JOBS:-1} "$@" 2>&1 | grep -v "cycles\|CUEW\|^$" | tail -${TAILN:-25}
if [ "${PIPESTATUS[0]}" != "0" ]; then echo "EXPORT FAILED"; exit 1; fi
nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$GLOB" 2>&1 | grep -v "^Godot Engine\|^$" | tail -12
nice -n 10 python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -2
