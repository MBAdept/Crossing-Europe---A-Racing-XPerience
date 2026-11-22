#!/bin/bash
# a mountain stage at night, threaded streaming (no --gfx-sync), 15 min wall: chunks evicted while being committed?
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT
MAXS=900 bash $S/sh/perf.sh mtn_night /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-5 modern deck saragossa_pau 22 normal 4 16 160,175,190,200 --start-km=150
grep -c 'lights.gd:563' $S/perf/mtn_night.log
grep -E 'SCRIPT ERROR' $S/perf/mtn_night.log | sort | uniq -c | head
