#!/bin/bash
# KRITIK-R3: tools/golden.sh check (once) on the copy heads/r4, nice 19 (the script itself starts every run at nice 10)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3
export XDG_DATA_HOME=$S/xdg/golden
mkdir -p $XDG_DATA_HOME
cd $S/heads/r4
t0=$(date +%s)
JOBS=1 nice -n 19 tools/golden.sh check > $S/logs/golden_r4.log 2>&1
code=$?
echo "golden exit $code ($(( $(date +%s) - t0 )) s)" | tee -a $S/logs/golden_r4.log
