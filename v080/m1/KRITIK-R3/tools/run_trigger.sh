#!/bin/bash
# KRITIK-R3: the reviewer's triggering check (kc_trigger.gd, all visible stages x 2 directions) on the copy heads/r4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3
export XDG_DATA_HOME=$S/xdg/trigger
mkdir -p $XDG_DATA_HOME
cd $S/heads/r4
nice -n 19 timeout 1800 godot --headless --path $S/heads/r4 -s $S/tools/kc_trigger.gd -- --graphics=arcade > $S/res/trigger_r4.log 2> $S/logs/trigger_r4.err
echo "exit $?"
tail -2 $S/res/trigger_r4.log
grep -c "^PLAN " $S/res/trigger_r4.log
grep -i "error" $S/logs/trigger_r4.err | head -5
