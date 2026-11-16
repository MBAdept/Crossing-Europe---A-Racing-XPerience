#!/bin/bash
# usage: run_filter.sh <filter> <logname>   – one test file on the copy heads/r4, nice 19, own XDG_DATA_HOME
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R3
export XDG_DATA_HOME=$S/xdg/filter
mkdir -p $XDG_DATA_HOME
cd $S/heads/r4
nice -n 19 timeout 900 godot --headless --path $S/heads/r4 -s res://tests/run_tests.gd -- --filter=$1 > $S/logs/$2.log 2>&1
echo "exit $?"
grep -E "^(FAIL|PASS|OK)|Tests|fehlgeschlagen|SCRIPT ERROR" $S/logs/$2.log | tail -8
