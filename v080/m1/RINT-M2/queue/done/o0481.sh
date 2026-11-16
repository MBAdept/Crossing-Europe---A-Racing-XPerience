cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
x=$S/xdg/o048; rm -rf $x; mkdir -p $x
XDG_DATA_HOME=$x nice -n 10 timeout 5400 godot --headless --path . -s $S/bin/jobpath.gd > $S/logs/jobpath_full.log 2>&1
echo "jobpath exit $?: $(grep JOBPATH-SUMMARY $S/logs/jobpath_full.log)"
grep -c JOBPATH-SLOW $S/logs/jobpath_full.log
