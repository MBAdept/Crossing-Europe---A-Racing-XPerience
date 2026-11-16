#!/bin/bash
# unit tests only (tests/run_tests.gd with a filter); $1 = filter, $2 = log tag
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
export XDG_DATA_HOME=$S/xdg
cd $W
nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- "--filter=$1" > $S/logs/unit_$2.log 2>&1
echo "exit $?"
grep -E 'FAIL|SCRIPT ERROR|Parse Error|bestanden|fehlgeschlagen|Tests:' $S/logs/unit_$2.log | tail -15
