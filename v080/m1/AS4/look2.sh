#!/usr/bin/env bash
# AS4 scratch: bake all props once -> import -> manifest -> contact sheets day/night for each named model.
#   look2.sh <prefix> <id> [<id> ...]       (sheets: look/<prefix>_<name>_tag.png / _nacht.png, large tiles, lod0+lod1)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$S/look"
cd "$WT"
PREFIX="$1"; shift
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="props/*" 2>&1 | grep -E "Fehler|FEHLER|ERROR" | tail -4
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -1
for id in "$@"; do
	n=${id#*/}
	nice -n 19 tools/models_contact_sheet.sh "$S/look/${PREFIX}_${n}_tag.png" --only="$id" --tile=900x640 --cols=2 2>&1 | grep -E "ERROR|SCRIPT|kein" | head -3
	nice -n 19 tools/models_contact_sheet.sh "$S/look/${PREFIX}_${n}_nacht.png" --only="$id" --night --tile=900x640 --cols=2 --lods=lod0 2>&1 | grep -E "ERROR|SCRIPT|kein" | head -3
done
echo fertig
