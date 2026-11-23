#!/bin/bash
# realbuild over all 128 directions: $1 = label, $2 = tree
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a
export XDG_DATA_HOME=$S/xdg
for pair in "$@"; do
	label=${pair%%=*}
	tree=${pair#*=}
	while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
	cd "$tree" && nice -n 10 timeout 3600 godot --headless --path . -s $S/probe/realbuild.gd -- --stage=all --dump=$S/logs/dump_all_$label.txt > $S/logs/realbuild_all_$label.log 2>&1
	echo "$label exit=$?"
	grep "REAL TOTAL" $S/logs/realbuild_all_$label.log
done
