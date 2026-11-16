#!/bin/bash
# Runs a Godot script under Xvfb (software OpenGL): xs.sh <logname> <res://script.gd> [args after --]
# Output: $S/logs/<logname>.log ; prints RENDER-CHECK / CHECK / ERROR lines and the exit code.
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
name="$1"; shift
script="$1"; shift
start=$(date +%s)
timeout 1800 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--fixed-fps 60 -s "$script" -- --graphics=modern --gfx-sync --audio-sync "$@" > "$S/logs/$name.log" 2>&1
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s  (log $S/logs/$name.log)"
grep -E "RENDER-CHECK|CHECK|FEHLER|SCRIPT ERROR|Parse Error|ERROR:|SHADER ERROR|==>" "$S/logs/$name.log" | awk '!seen[$0]++' | head -60
