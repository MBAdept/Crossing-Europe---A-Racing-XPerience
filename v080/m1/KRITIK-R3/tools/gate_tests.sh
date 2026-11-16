#!/bin/bash
# KRITIK-R3: tools/run_tests.sh (complete, once) on the copy heads/r4, nice 19, own absolute XDG_DATA_HOME
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3
export XDG_DATA_HOME=$S/xdg/run_tests
mkdir -p $XDG_DATA_HOME
cd $S/heads/r4
t0=$(date +%s)
nice -n 19 tools/run_tests.sh > $S/logs/run_tests_r4.log 2>&1
code=$?
echo "run_tests exit $code ($(( $(date +%s) - t0 )) s)" | tee -a $S/logs/run_tests_r4.log
