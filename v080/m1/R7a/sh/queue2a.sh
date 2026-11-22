#!/bin/bash
# R7a: second queue – base pictures where something changed, the roof R1 again (closer), occlusion, perf, clip.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export TMPDIR=$S/tmp
echo "$(date -u +%H:%M:%S) start"
bash "$S/sh/shots.sh" mine high Hannover R1 R2 R3 R4 R5
bash "$S/sh/shots.sh" base high R1 S0 Lyon Muenchen Belgrad Hannover
echo "$(date -u +%H:%M:%S) done"
