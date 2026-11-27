#!/bin/bash
# W6: after the test fixes (capped_turn, test manifests): the landmark and prop unit tests, the props render check
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
G=$W6/gates; L=$W6/logs/gates.log
cd $WT
for f in landmarks props; do
	t0=$(date +%s)
	XDG_DATA_HOME=$W6/xdg_tests nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- "--filter=$f" > $G/unit_$f.log 2>&1
	rc=$?; grep -qE "SCRIPT ERROR|Parse Error" $G/unit_$f.log && rc=1
	echo "$(date +%T) GATE unit_$f rc $rc $(( $(date +%s) - t0 )) s $(grep -E '[0-9]+ Tests' $G/unit_$f.log | tail -1)" >> $L
done
t0=$(date +%s)
nice -n 10 tools/run_render_checks.sh modern props_render > $G/render_props.log 2>&1
echo "$(date +%T) GATE render_props rc $? $(( $(date +%s) - t0 )) s" >> $L
echo "$(date +%T) GATES5 DONE" >> $L
