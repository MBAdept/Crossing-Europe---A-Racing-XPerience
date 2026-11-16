#!/bin/bash
# queue3.sh – after queue2: check_night_nass on the head with pictures, then tools/golden.sh modern-check (KEEP pictures)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7
L=$S/gates/queue3.log
until grep -q QUEUE2_DONE $S/gates/queue2.log; do sleep 10; done
echo "== head_nass start $(date +%T)" >> $L
$S/sh/rcd.sh head check_night_nass.gd nass >> $L 2>&1
echo "== head_nass exit=$? $(date +%T)" >> $L
echo "== modern start $(date +%T)" >> $L
mkdir -p $S/gates/modern_keep
cd "$WT" && TMPDIR=$S/tmp KEEP=$S/gates/modern_keep MESA_SHADER_CACHE_DIR=$S/mesa_golden nice -n 10 tools/golden.sh modern-check > $S/gates/modern.log 2>&1
echo "== modern exit=$? $(date +%T)" >> $L
grep -E "GOLDEN|ANDERS|identisch" $S/gates/modern.log >> $L
echo "QUEUE3_DONE $(date +%T)" >> $L
