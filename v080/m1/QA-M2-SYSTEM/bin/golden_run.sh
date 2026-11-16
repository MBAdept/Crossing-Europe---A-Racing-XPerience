#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
cd $WT
rm -rf $S/golden_keep; mkdir -p $S/golden_keep $S/xdg_golden
echo "START golden $(date -u +%H:%M:%S) load $(cut -d' ' -f1 /proc/loadavg)" >> $S/queue.log
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_golden KEEP=$S/golden_keep tools/golden.sh check > $S/q_golden.log 2>&1
rc=$?
echo "DONE golden exit=$rc $((SECONDS - t0)) s $(date -u +%H:%M:%S)" >> $S/queue.log
