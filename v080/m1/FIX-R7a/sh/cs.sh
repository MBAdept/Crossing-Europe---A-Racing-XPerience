#!/usr/bin/env bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-8
export XDG_DATA_HOME=$S/xdg
nice -n 10 timeout 300 godot --headless --path . -s res://tests/check_scripts.gd > $S/logs/check_scripts.log 2>&1
echo "exit $?"
grep -E "KAPUTT|geprüft|SCRIPT ERROR|Parse Error|at: GDScript" $S/logs/check_scripts.log | head -30
