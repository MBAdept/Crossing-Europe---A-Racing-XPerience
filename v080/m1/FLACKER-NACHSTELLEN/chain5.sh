#!/bin/bash
# Waits until no other FLACKER-NACHSTELLEN queue runs, then: ZS1 jobs4a (skips DONE), M2 checkout + import, jobs4m.
# Safe to start again after a restart (every step skips what is done).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN
while pgrep -f "FLACKER-NACHSTELLEN/(chain4|queue4).sh" > /dev/null; do sleep 30; done
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_17007edf-ec9-1
if [ "$(git -C "$W" rev-parse HEAD)" = "39849f0263921f798da4326b83dff30d83a947d2" ]; then
	bash $S/queue4.sh $S/jobs4a.txt
fi
bash $S/m2_prepare.sh
bash $S/queue4.sh $S/jobs4m.txt
echo "CHAIN5 END $(date +%T)" >> $S/queue4.state
