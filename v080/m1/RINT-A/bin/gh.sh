#!/bin/bash
# Runs a scratch GDScript (absolute path) headless against the worktree: gh.sh <logname> </abs/script.gd> [args]
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
name="$1"; shift
script="$1"; shift
start=$(date +%s)
timeout 1800 nice -n 10 godot --headless --path . -s "$script" -- --graphics=modern "$@" > "$S/logs/$name.log" 2>&1
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s  (log $S/logs/$name.log)"
grep -E "RINT|SCRIPT ERROR|Parse Error" "$S/logs/$name.log" | head -30
