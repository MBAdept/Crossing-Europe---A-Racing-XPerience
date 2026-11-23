#!/usr/bin/env bash
# unit tests filtered: ut.sh <filter> [logname]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-8
export XDG_DATA_HOME=$S/xdg
L=$S/logs/${2:-ut_$1}.log
nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- "--filter=$1" > $L 2>&1
echo "exit $?"
grep -E "FAIL|SCRIPT ERROR|Parse Error|^ERROR|Tests:|passed|failed|bestanden|fehlgeschlagen" $L | head -40
