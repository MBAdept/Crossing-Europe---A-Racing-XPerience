#!/usr/bin/env bash
# AS4 scratch: bake -> import -> manifest -> contact sheets by day and at night (no export).
#   look.sh "<glob>" <name> [extra contact sheet args...]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$S/look"
cd "$WT"
GLOB="$1"; shift
NAME="$1"; shift
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$GLOB" 2>&1 | grep -vE "^Godot|^\s*$|^AudioManager" | tail -4
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -1
nice -n 19 tools/models_contact_sheet.sh "$S/look/${NAME}_tag.png" --only="$GLOB" "$@" 2>&1 | tail -2
nice -n 19 tools/models_contact_sheet.sh "$S/look/${NAME}_nacht.png" --only="$GLOB" --night "$@" 2>&1 | tail -2
