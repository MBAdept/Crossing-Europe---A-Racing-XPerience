#!/bin/bash
# AU-C2 gates: Arcade check, modern-check (KEEP), whole suite, audio QC with determinism, all render checks.
# Each finished step leaves <step>.done (a restart skips it). Log $S/logs/gates.log; ends with "GATES AUC2 DONE".
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AUC2/env.sh
cd $WT
G=$S/gates; mkdir -p $G $S/tmp_golden $S/xdg_tests
step() { local n=$1; shift; [ -f $G/$n.done ] && return; local t0=$(date +%s); "$@" > $G/$n.log 2>&1; local rc=$?
	echo "$(date +%T) GATE $n rc $rc $(( $(date +%s) - t0 )) s" >> $S/logs/gates.log; echo $rc > $G/$n.done; }
echo "$(date +%T) GATES AUC2 start head $(git rev-parse --short HEAD)" >> $S/logs/gates.log
step check env TMPDIR=$S/tmp_golden KEEP=$G/arcade_check nice -n 10 tools/golden.sh check
step modern env TMPDIR=$S/tmp_golden KEEP=$G/modern_keep nice -n 10 tools/golden.sh modern-check
step run_tests env XDG_DATA_HOME=$S/xdg_tests nice -n 10 tools/run_tests.sh
step qc_det nice -n 10 python3 tools/audio/qc/audio_qc.py --determinism
step render_all nice -n 10 tools/run_render_checks.sh all
echo "$(date +%T) GATES AUC2 DONE" >> $S/logs/gates.log
