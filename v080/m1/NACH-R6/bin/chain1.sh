#!/usr/bin/env bash
# NACH-R6 chain 1: B-04 mutations (restored after each), then the headless scans and the collect() timing.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
echo "== mutations"
python3 $S/bin/mutate.py
echo "== scans"
$S/bin/scans.sh scan_f1 scan_all startdep collect_time
echo "== chain1 done"
