#!/bin/bash
# N6: render check of the landmarks, golden modern-check (pictures kept), the whole test suite
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
G=$W6/gates_n6; L=$W6/logs/gates.log; mkdir -p $G
cd $WT
step() { local n=$1; shift; [ -f $G/$n.done ] && return; local t0=$(date +%s); "$@" > $G/$n.log 2>&1; local rc=$?
	echo "$(date +%T) GATE n6_$n rc $rc $(( $(date +%s) - t0 )) s" >> $L; echo $rc > $G/$n.done; }
echo "$(date +%T) GATES N6 start head $(git rev-parse --short HEAD)" >> $L
step render_lm nice -n 10 tools/run_render_checks.sh modern landmarks
step modern env TMPDIR=$W6/tmp_golden KEEP=$G/modern_keep nice -n 10 tools/golden.sh modern-check
step golden env TMPDIR=$W6/tmp_golden nice -n 10 tools/golden.sh check
step run_tests env XDG_DATA_HOME=$W6/xdg_tests nice -n 10 tools/run_tests.sh
echo "$(date +%T) GATES N6 DONE" >> $L
