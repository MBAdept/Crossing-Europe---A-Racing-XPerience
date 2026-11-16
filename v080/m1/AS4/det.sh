#!/usr/bin/env bash
# AS4 scratch: determinism check - forced re-export of every props model, bake, import, manifest;
# afterwards the working tree must be clean (byte-identical files).
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$WT"
t0=$(date +%s)
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only='props/*' --force --jobs=1 2>&1 | grep -E "^EXPORT|Error|Traceback|FEHLER|Exception" | head -40
t1=$(date +%s)
echo "Export: $((t1 - t0)) s"
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only='props/*' 2>&1 | grep -vE "^Godot|^\s*$|^AudioManager" | tail -8
t2=$(date +%s)
echo "Bake: $((t2 - t1)) s"
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only 2>&1 | tail -2
echo "=== git status (leer = byte-identisch)"
git status --porcelain
echo "=== Ende"
