#!/bin/bash
# QA-R7a: Arcade identity gate (tools/golden.sh check) on the R7a worktree
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-5
rm -f /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R7a/r7a/S0_deck*
mkdir -p "$S/xdg_gold" "$S/tmp"
cd "$WT" || exit 2
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_gold MESA_SHADER_CACHE_DIR=$S/mesa LP_NUM_THREADS=2 TMPDIR=$S/tmp nice -n 10 timeout 3000 tools/golden.sh check > "$S/logs/golden_check.log" 2>&1
echo "$(date -u +%H:%M:%S) golden exit=$? $((SECONDS - t0)) s"
grep GOLDEN "$S/logs/golden_check.log"
touch "$S/done/golden"
