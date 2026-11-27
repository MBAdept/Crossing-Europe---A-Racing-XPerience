#!/bin/bash
# HUD/radar user request (A-32): Arcade reference = v0.7.0 + tests/golden/arcade_ref.patch (make, kept pictures),
# then check against the working copy, modern change detectors (kept), whole test suite, all render checks
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
G=$W6/gates_hud; L=$W6/logs/gates.log; mkdir -p $G
cd $WT
step() { local n=$1; shift; [ -f $G/$n.done ] && return; local t0=$(date +%s); "$@" > $G/$n.log 2>&1; local rc=$?
	echo "$(date +%T) GATE hud_$n rc $rc $(( $(date +%s) - t0 )) s" >> $L; echo $rc > $G/$n.done; }
echo "$(date +%T) GATES HUD start head $(git rev-parse --short HEAD) (+ Arbeitsstand)" >> $L
[ -f $G/old_arcade_v070.md5 ] || { git show HEAD:tests/golden/arcade_v070.md5 > $G/old_arcade_v070.md5; git show HEAD:tests/golden/arcade_ui_v070.md5 > $G/old_arcade_ui_v070.md5; }
step make env TMPDIR=$W6/tmp_golden KEEP=$G/arcade_ref nice -n 10 tools/golden.sh make
step check env TMPDIR=$W6/tmp_golden KEEP=$G/arcade_check nice -n 10 tools/golden.sh check
step modern env TMPDIR=$W6/tmp_golden KEEP=$G/modern_keep nice -n 10 tools/golden.sh modern-check
step run_tests env XDG_DATA_HOME=$W6/xdg_tests nice -n 10 tools/run_tests.sh
step render_all nice -n 10 tools/run_render_checks.sh all
echo "$(date +%T) GATES HUD DONE" >> $L
