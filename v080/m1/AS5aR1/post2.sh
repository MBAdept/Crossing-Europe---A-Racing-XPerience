#!/usr/bin/env bash
# AS5aR1: A/B in the race (three city arrivals of the batch + München), then the gates (tests, Arcade identity,
# Modern change detectors). One heavy job after the other.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
source $S/env.sh
echo "start $(date +%H:%M)"
$S/ab_run.sh "hh:high:12 nu:high:12 hn:high:12 hh:high:22 nu:high:22 hn:high:22 hh:medium:19.5 nu:medium:19.5 hn:medium:19.5 mu:high:12"
cd $WT
rm -rf tools/kritik
waitmem
XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh > $S/logs/gate_tests.log 2>&1
echo "TESTS exit $? $(date +%H:%M): $(tail -3 $S/logs/gate_tests.log | tr '\n' ' ')"
waitmem
nice -n 19 tools/golden.sh check > $S/logs/gate_golden.log 2>&1
echo "GOLDEN exit $? $(date +%H:%M): $(grep -E 'GOLDEN' $S/logs/gate_golden.log | tr '\n' ' ')"
waitmem
rm -rf $S/golden_modern; mkdir -p $S/golden_modern
KEEP=$S/golden_modern nice -n 19 tools/golden.sh modern-check > $S/logs/gate_mcheck.log 2>&1
echo "MCHECK exit $? $(date +%H:%M): $(grep -E 'GOLDEN' $S/logs/gate_mcheck.log | tr '\n' ' ')"
waitmem
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys > $S/logs/gate_checkkeys.log 2>&1
echo "CHECKKEYS exit $? $(date +%H:%M): $(grep -E 'CHECK' $S/logs/gate_checkkeys.log | tr '\n' ' ')"
echo "=== post2 fertig $(date +%H:%M)"
