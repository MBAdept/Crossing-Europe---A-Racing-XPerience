#!/bin/bash
# after the restart at 23:32: the rest of chain1 (render checks, occlusion probe), then the Modern goldens (chain5)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
$S/sh/gates.sh render
echo "RENDER DONE $(date +%T)"
$S/sh/occl.sh head T1 T2 T3 T4 C1 S0 S4
$S/sh/occl.sh base T1 T2 T3 T4 C1 S0 S4
echo "OCCL DONE $(date +%T)"
mkdir -p $S/tmp_golden $S/gates/modern_make
cd $W
t0=$SECONDS
KEEP=$S/gates/modern_make TMPDIR=$S/tmp_golden nice -n 10 tools/golden.sh modern-make > $S/gates/modern_make.log 2>&1
echo "MAKE rc=$? $((SECONDS - t0)) s"
git -C $W status --short | head
echo "MAKE DONE $(date +%T)"
