#!/bin/bash
# RINT-M3 note 12: once chain1 (gates, occlusion) is done, render the Modern goldens on the head (modern-make);
# the lead commits them after a look at the diff, then starts the final checks and builds (chain6)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
until grep -q 'CHAIN1 DONE' $S/logs/chain1.log 2>/dev/null; do sleep 30; done
mkdir -p $S/tmp_golden $S/gates/modern_make
cd $W
t0=$SECONDS
KEEP=$S/gates/modern_make TMPDIR=$S/tmp_golden nice -n 10 tools/golden.sh modern-make > $S/gates/modern_make.log 2>&1
echo "MAKE rc=$? $((SECONDS - t0)) s"
git -C $W status --short | head
echo "MAKE DONE $(date +%T)"
