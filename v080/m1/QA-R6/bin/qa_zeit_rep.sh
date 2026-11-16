#!/usr/bin/env bash
# QA-R6: repeat the renderer timing check, alternating head (mut) and base, N rounds
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
N=${1:-3}
for i in $(seq 1 $N); do
	for pr in mut base; do
		mkdir -p $S/xdg/qz_$pr
		cd $S/$pr || exit 1
		XDG_DATA_HOME=$S/xdg/qz_$pr nice -n 10 timeout 900 godot --headless --path . -s res://tests/race3d/check_qa_zeit.gd -- --graphics=modern > $S/gates/qa_zeit_${pr}_rep$i.log 2>&1
	done
done
echo done
