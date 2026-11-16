#!/bin/bash
# usage: ab_all.sh <tag>   -> in-game engine captures (Arcade and Modern) of the scripted drive for all five cars
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
TAG=${1:-ab1}
OUT=$W/ab/$TAG
mkdir -p "$OUT" "$W/../xdg_ab"
export XDG_DATA_HOME=$W/../xdg_ab
cd "$R" || exit 1
for car in ${CARS:-kompakt kombi limousine sportwagen gran_turismo}; do
	for prof in ${PROFILES:-arcade modern}; do
		nice -n 5 godot --headless --path . -s "$W/ab_capture.gd" -- --graphics=arcade --sound=$prof --vehicle=$car --out="$OUT/${car}_${prof}.wav" 2>&1 | grep -E 'ERROR|WARNING|ab_capture' | sed -e 's#/tmp/claude-0/[^ ]*/work/##g' | cut -c1-330
	done
done
echo FERTIG
