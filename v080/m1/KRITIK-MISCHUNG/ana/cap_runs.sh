#!/usr/bin/env bash
# KRITIK-MISCHUNG: recordings of the Modern game mix at fixed speeds (sequential, nice 19, one process).
# usage: cap_runs.sh <variant> [<variant> …]   variants: gt_car gt_wind gt_engine gt_tyres sw_car gt_music gt_all
set -u
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-MISCHUNG
OUT=$K/cap
mkdir -p "$OUT" "$K/xdg"
cd "$K/copy" || exit 1
for v in "$@"; do
	case $v in
		gt_car) args="--vehicle=gran_turismo --mute-bus=MMusic" ;;
		gt_wind) args="--vehicle=gran_turismo --mute-bus=MMusic,MEngine,MEngineFx,MRoad" ;;
		gt_engine) args="--vehicle=gran_turismo --mute-bus=MMusic,MRoad,MWind" ;;
		gt_tyres) args="--vehicle=gran_turismo --mute-bus=MMusic,MEngine,MEngineFx,MWind" ;;
		sw_car) args="--vehicle=sportwagen --mute-bus=MMusic" ;;
		kp_car) args="--vehicle=kompakt --mute-bus=MMusic" ;;
		gt_music) args="--vehicle=gran_turismo --music --mute-bus=MEnv" ;;
		gt_all) args="--vehicle=gran_turismo --music" ;;
		*) echo "unbekannt: $v"; continue ;;
	esac
	echo "== $v $(date +%T)"
	XDG_DATA_HOME="$K/xdg" nice -n 19 timeout 400 godot --headless --path . -s res://kritik_tools/mix_speeds.gd -- \
		--sound=modern --graphics=arcade --out="$OUT/$v.wav" $args > "$K/logs/cap_$v.log" 2>&1
	echo "   exit $? $(date +%T)"
	grep -E "mix_speeds:|phase|Start bei|SCRIPT ERROR|ERROR" "$K/logs/cap_$v.log" | head -20
done
echo "== fertig"
