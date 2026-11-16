#!/usr/bin/env bash
# card style experiments on one tree model: exp_cards.sh <model> <tag> VAR=value ...
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1b
export XDG_DATA_HOME=$S/xdg MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
M="$1"; TAG="$2"; shift 2
env "$@" nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$M" --jobs=1 --force 2>&1 | grep -E "^EXPORT|Error|Trace"
nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$M" > /dev/null 2>&1
nice -n 10 godot --headless --path . --import > /dev/null 2>&1
nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only > /dev/null 2>&1
nice -n 10 tools/models_prop_scene.sh "$S/exp_$TAG.png" --models="$M" --tile=420x380 --dist=25,40,100 2>&1 | grep -v "^/"
