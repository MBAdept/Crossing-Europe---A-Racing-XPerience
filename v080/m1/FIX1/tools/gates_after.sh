#!/bin/bash
# FIX1: the gates after run_tests.sh, one after the other (heavy jobs never in parallel).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-4
G=$S/gates
mkdir -p $G $S/xdg/golden $S/xdg/render $S/golden_keep
cd $WT || exit 1
echo "== golden $(date +%T)"
XDG_DATA_HOME=$S/xdg/golden KEEP=$S/golden_keep nice -n 10 tools/golden.sh check > $G/golden.log 2>&1
echo "golden exit=$?" >> $G/golden.log
tail -3 $G/golden.log
echo "== render checks $(date +%T)"
XDG_DATA_HOME=$S/xdg/render MESA_SHADER_CACHE_DIR=$S/mesa_rc nice -n 10 tools/run_render_checks.sh all > $G/render_checks.log 2>&1
echo "render exit=$?" >> $G/render_checks.log
grep -E "RENDER-CHECK-DATEI|exit=" $G/render_checks.log | tail -30
echo "== A/B $(date +%T)"
MODES=modern ARCADE_REF=$S/../QA-BILD/ab_med $S/tools/ab.sh $S/ab5 medium S4 -- --shot-times=2,6 > $G/ab5.log 2>&1
MODES=modern ARCADE_REF=$S/../QA-BILD/ab_var $S/tools/ab.sh $S/ab5 medium S2H22 S1H22 -- --shot-times=2,6 >> $G/ab5.log 2>&1
cat $G/ab5.log
echo "== done $(date +%T)"
