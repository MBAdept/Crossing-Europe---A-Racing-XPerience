#!/bin/bash
# Runs a headless Godot script of the worktree: gs.sh <logname> <res://script.gd> [args after --]
# Output: $S/logs/<logname>.log ; prints the CHECK / FEHLER / ERROR lines and the exit code.
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
name="$1"; shift
script="$1"; shift
start=$(date +%s)
if [ $# -gt 0 ]; then
  timeout 1800 nice -n 10 godot --headless --path . -s "$script" -- "$@" > "$S/logs/$name.log" 2>&1
else
  timeout 1800 nice -n 10 godot --headless --path . -s "$script" > "$S/logs/$name.log" 2>&1
fi
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s  (log $S/logs/$name.log)"
grep -E "CHECK|FEHLER|SCRIPT ERROR|Parse Error|ERROR:|KAPUTT|Skripte geprüft|==>|bestanden|fehlgeschlagen" "$S/logs/$name.log" | head -60
