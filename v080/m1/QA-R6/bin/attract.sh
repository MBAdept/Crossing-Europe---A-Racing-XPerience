#!/usr/bin/env bash
# QA-R6: check_attract (Arcade) three times each on head (mut copy) and base, alternating
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
OUT=$S/gates/attract_rerun.txt
for i in 1 2 3; do
	for pr in mut base; do
		mkdir -p $S/xdg/att_$pr
		cd $S/$pr || exit 1
		r=$(XDG_DATA_HOME=$S/xdg/att_$pr nice -n 10 timeout 300 godot --headless --path . -s res://tests/race/check_attract.gd -- --graphics=arcade 2>&1 | grep -E "CHECK idle|CHECKS")
		echo "$pr run $i load $(cut -d' ' -f1 /proc/loadavg): $r" | tr '\n' ' ' >> $OUT
		echo >> $OUT
	done
done
