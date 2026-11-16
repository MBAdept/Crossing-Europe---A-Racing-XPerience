#!/usr/bin/env bash
# NACH-R6: Arcade identity (once), then the Modern change detector for the start frame (renewed by FIX-R6).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4
cd "$W" || exit 1
export XDG_DATA_HOME=$S/xdg_golden
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME"
t0=$(date +%s)
nice -n 10 tools/golden.sh check > $S/logs/golden_check.log 2>&1
echo "golden check exit $? $(( $(date +%s) - t0 )) s"
grep -E "^GOLDEN" $S/logs/golden_check.log
t0=$(date +%s)
KEEP=$S/golden_keep nice -n 10 tools/golden.sh modern-check start > $S/logs/golden_modern_start.log 2>&1
echo "golden modern-check start exit $? $(( $(date +%s) - t0 )) s"
grep -E "^GOLDEN" $S/logs/golden_modern_start.log
git status --short
