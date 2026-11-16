#!/bin/bash
# FIX-M2: forest instance check once (timing), log logs/wald_<tag>.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-5
X=$S/xdg/rc_wald; mkdir -p $X
t0=$SECONDS
XDG_DATA_HOME=$X MESA_SHADER_CACHE_DIR=$S/mesa RENDER_CHECK_TIMEOUT=900 tools/run_render_checks.sh modern instance_budget > $S/logs/wald_$1.log 2>&1
echo "exit $? $((SECONDS - t0)) s load $(cat /proc/loadavg)" >> $S/logs/wald_$1.log
