#!/bin/bash
# FIX-RINT gates on the final head, one heavy job at a time
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4
export MESA_SHADER_CACHE_DIR=$S/mesa
export TMPDIR=$S/tmp
export LP_NUM_THREADS=2
mkdir -p $TMPDIR $S/xdg/rt2 $S/xdg/golden $S/xdg/golden_m $S/xdg/rc_all
cd $W
echo "gates: head $1 $(date +%T)"
echo "=== run_tests $(date +%T)"
XDG_DATA_HOME=$S/xdg/rt2 nice -n 10 tools/run_tests.sh > $S/logs/run_tests2.log 2>&1
echo "run_tests exit $?"
tail -8 $S/logs/run_tests2.log
echo "=== golden check $(date +%T)"
XDG_DATA_HOME=$S/xdg/golden nice -n 10 tools/golden.sh check > $S/logs/golden_check.log 2>&1
echo "golden exit $?"
grep -E "^GOLDEN" $S/logs/golden_check.log
echo "=== modern-check $(date +%T)"
rm -rf $S/shots/modern_keep
mkdir -p $S/shots/modern_keep
KEEP=$S/shots/modern_keep XDG_DATA_HOME=$S/xdg/golden_m nice -n 10 tools/golden.sh modern-check > $S/logs/modern_check.log 2>&1
echo "modern-check exit $?"
grep -E "^GOLDEN" $S/logs/modern_check.log
echo "=== render checks $(date +%T)"
XDG_DATA_HOME=$S/xdg/rc_all nice -n 10 tools/run_render_checks.sh all > $S/logs/rc_all.log 2>&1
echo "render exit $?"
grep -E "RENDER-CHECK-DATEI|FEHLER" $S/logs/rc_all.log | head -60
echo "gates done $(date +%T)"
