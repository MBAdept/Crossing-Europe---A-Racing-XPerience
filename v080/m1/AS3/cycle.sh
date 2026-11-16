#!/usr/bin/env bash
# AS3 scratch: export -> bake -> import -> manifest for a model glob (one worker, lowest priority).
#   cycle.sh "<glob>" [--force]
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
GLOB="$1"; shift
t0=$(date +%s)
nice -n 19 "$BPY" tools/blender/export_models.py --only="$GLOB" --jobs=1 "$@" 2>&1 | grep -E "^EXPORT|Error|Traceback|line [0-9]|FEHLER|Exception|RuntimeError|ValueError|IndexError|KeyError|TypeError|NameError|AttributeError" | head -40
t1=$(date +%s)
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$GLOB" 2>&1 | grep -vE "^Godot|^\s*$|^AudioManager" | tail -12
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 "$BPY" tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "cycle: export $((t1 - t0)) s, gesamt $(( $(date +%s) - t0 )) s"
