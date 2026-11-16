#!/bin/bash
# import + check_scripts in the RINT-M2 worktree; $1 = log tag
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
export XDG_DATA_HOME=$S/xdg
cd $W
nice -n 10 timeout 1200 godot --headless --path . --import > $S/logs/import_$1.log 2>&1
echo "import exit $?"
grep -iE 'error|failed' $S/logs/import_$1.log | grep -v 'loading_editor' | head -20
nice -n 10 timeout 600 godot --headless --path . -s res://tests/check_scripts.gd > $S/logs/checkscripts_$1.log 2>&1
echo "check_scripts exit $?"
tail -3 $S/logs/checkscripts_$1.log
