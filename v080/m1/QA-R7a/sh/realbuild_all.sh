#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a
export XDG_DATA_HOME=$S/xdg
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-5 && nice -n 19 timeout 3600 godot --headless --path . -s $S/probe/realbuild.gd -- --stage=all --dump=$S/logs/dump_all_r7a.txt > $S/logs/realbuild_all_r7a.log 2>&1
echo "r7a exit=$?"
cd $S/base && nice -n 19 timeout 3600 godot --headless --path . -s $S/probe/realbuild.gd -- --stage=all --dump=$S/logs/dump_all_base.txt > $S/logs/realbuild_all_base.log 2>&1
echo "base exit=$?"
