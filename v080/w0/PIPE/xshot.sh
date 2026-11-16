#!/bin/bash
# runs the probe in the root window and takes an external X screenshot
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2
godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1600x100 -s /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE/probe_color3.gd > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE/xshot.log 2>&1 &
PID=$!
sleep 5
import -window root /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE/xshot.png
wait $PID
