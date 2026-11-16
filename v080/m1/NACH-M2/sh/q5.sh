#!/bin/bash
# NACH-M2 queue 5 (after q4): rerun the timing cases of the full run alone, head then base (6e48405).
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-M2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-6
L=$N/logs/q5.log
while ! grep -q Q4-DONE $N/logs/q4.log 2>/dev/null; do sleep 20; done
for tree in head base; do
	d=$WT
	[ $tree = base ] && d=$N/base
	for f in test_engine3_checks test_music_checks; do
		X=$N/xdg/r_${tree}_$f; rm -rf "$X"; mkdir -p "$X"
		(cd $d && XDG_DATA_HOME=$X nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- --filter=$f) > $N/logs/rerun_${tree}_$f.log 2>&1
		echo "$(date -u +%T) $tree $f exit=$? $(grep -E 'Tests,' $N/logs/rerun_${tree}_$f.log)" >> $L
		rm -rf "$X"
	done
	X=$N/xdg/r_${tree}_attract; rm -rf "$X"; mkdir -p "$X"
	(cd $d && XDG_DATA_HOME=$X nice -n 10 timeout 900 godot --headless --path . -s res://tests/race/check_attract.gd -- --graphics=arcade) > $N/logs/rerun_${tree}_attract.log 2>&1
	echo "$(date -u +%T) $tree attract exit=$? $(grep -E 'CHECK idle|CHECKS' $N/logs/rerun_${tree}_attract.log | tr '\n' ' ')" >> $L
	rm -rf "$X"
done
echo "$(date -u +%T) Q5-DONE" >> $L
