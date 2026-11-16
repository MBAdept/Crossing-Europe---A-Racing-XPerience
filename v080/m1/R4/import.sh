#!/bin/bash
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
export XDG_DATA_HOME=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4/xdg
mkdir -p "$XDG_DATA_HOME"
nice -n 19 godot --headless --path . --import > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4/import.log 2>&1
echo "exit=$?" >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4/import.log
