#!/usr/bin/env bash
# capture_mix drive runs for the loudness plan: per car full mix, engine only, tyres only, wind only (sequential, nice 19)
set -u
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-C1
OUT=$S/cap
mkdir -p "$OUT" "$S/xdg_cap"
cd "$WT"
CARS=${CARS:-"gran_turismo kompakt"}
for car in $CARS; do
	for variant in full engine tyres wind; do
		case $variant in
			full) mute="" ;;
			engine) mute="--mute-bus=MRoad,MWind" ;;
			tyres) mute="--mute-bus=MEngine,MEngineFx,MWind" ;;
			wind) mute="--mute-bus=MEngine,MEngineFx,MRoad" ;;
		esac
		f="$OUT/${car}_${variant}.wav"
		echo "== $car $variant"
		XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 300 godot --headless --path . -s res://tools/audio/modern/capture_mix.gd -- \
			--sound=modern --scenario=drive --vehicle="$car" --out="$f" $mute 2>&1 | grep -E "capture_mix|ERROR|SCRIPT" | head -5
	done
done
echo "== fertig"
