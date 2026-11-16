#!/usr/bin/env bash
# AS4 scratch: export -> bake -> import -> manifest -> (contact sheet) for a model glob.
#   cycle.sh "<glob>" [sheet-name] [extra contact sheet args...]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$WT"
GLOB="$1"; shift
NAME="${1:-}"; [ $# -gt 0 ] && shift
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$GLOB" --jobs=1 2>&1 | grep -E "^EXPORT|Error|Traceback|line [0-9]|FEHLER|Exception" | head -30
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$GLOB" 2>&1 | grep -vE "^Godot|^\s*$|^AudioManager" | tail -8
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only 2>&1 | tail -2
if [ -n "$NAME" ]; then
	nice -n 19 tools/models_contact_sheet.sh "$S/$NAME.png" --only="$GLOB" "$@" 2>&1 | tail -2
fi
