#!/bin/bash
# check_instance_budget_wald alone on a quiet machine (tools/run_render_checks.sh nices itself: no outer nice).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
cd $WT
mkdir -p $S/xdg_wald
echo "START wald $(date -u +%H:%M:%S) load $(cut -d' ' -f1 /proc/loadavg)" >> $S/queue.log
t0=$SECONDS
( while sleep 60; do echo "load $(date -u +%H:%M:%S) $(cut -d' ' -f1-3 /proc/loadavg)"; done ) > $S/wald_load.log &
LP=$!
XDG_DATA_HOME=$S/xdg_wald RENDER_CHECK_TIMEOUT=3000 tools/run_render_checks.sh modern instance_budget_wald > $S/q_wald.log 2>&1
rc=$?
kill $LP
echo "DONE wald exit=$rc $((SECONDS - t0)) s $(date -u +%H:%M:%S)" >> $S/queue.log
