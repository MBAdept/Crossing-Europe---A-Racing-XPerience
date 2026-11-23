#!/bin/bash
# FIX-R7a queue 1: realbuild pushB (conservative envelope), footprint check head + pushB (full), then pictures pushB
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a/sh/common.sh
$S/sh/realbuild_runs.sh "pushB2=$PFIX"
for w in head pushB; do
	wt=$WT
	[ "$w" = pushB ] && wt=$PFIX
	memwait
	(cd "$wt" && nice -n 10 timeout 1800 godot --headless --path . -s res://tests/race3d/props_footprint.gd -- --full > $S/logs/footprint_full_$w.log 2>&1)
	echo "footprint $w exit=$?"
	grep -E "^FOOTPRINT [0-9]+ directions|CHECK" $S/logs/footprint_full_$w.log
done
for n in Muenchen T4 C1 Belgrad T2 Hannover S0; do
	shot pushB $n high
done
for n in C1 T4 T3; do
	occl pushB $n
done
echo QUEUE1_DONE
