#!/bin/bash
# Godot headless import of the RINT-B worktree; log into scratch
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
LOG=$S/import_$(date +%H%M%S).log
cd "$WT" || exit 1
nice -n 10 timeout 900 godot --headless --path . --import > "$LOG" 2>&1
code=$?
echo "exit=$code log=$LOG"
grep -iE "error|warning|failed" "$LOG" | grep -v "^\s*$" | head -20
exit $code
