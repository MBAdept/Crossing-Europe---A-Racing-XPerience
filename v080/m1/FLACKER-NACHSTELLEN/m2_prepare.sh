#!/bin/bash
# Switches the FLACKER-NACHSTELLEN worktree to the M2 head (detached, no commit) and re-imports. Idempotent.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_17007edf-ec9-1
M2=6e484056ec87e2fa614061000a362feb2b5a6db8
cd "$W" || exit 1
if [ "$(git rev-parse HEAD)" != "$M2" ]; then
	git checkout --detach "$M2" >> "$S/m2_prepare.log" 2>&1 || { echo "CHECKOUT FAILED" >> "$S/queue4.state"; exit 1; }
fi
echo "M2 checkout $(git rev-parse --short HEAD) $(date +%T)" >> "$S/queue4.state"
if ! grep -q "^M2 IMPORTED" "$S/queue4.state"; then
	XDG_DATA_HOME=$S/xdg nice -n 19 timeout 3000 godot --headless --path . --import >> "$S/m2_import.log" 2>&1
	echo "M2 IMPORTED $? $(date +%T)" >> "$S/queue4.state"
fi
