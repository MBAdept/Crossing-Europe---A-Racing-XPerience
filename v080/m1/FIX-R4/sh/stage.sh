#!/bin/bash
# stage.sh <tag> <tree> – whole Modern autopilot stage under Xvfb (Kiel – Hamburg, 21 Uhr, Regen; „Niedrig“, Zeitraffer 16
# – the same run as R4's m1/R4/sh/stage.sh); log in stage/<tag>.log; run one after the other for head and base
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
TAG=$1
TREE=$2
mkdir -p "$S/stage"
rm -rf "$S/stage/xdg_$TAG"
mkdir -p "$S/stage/xdg_$TAG"
cd "$TREE" || exit 2
T0=$(date +%s)
XDG_DATA_HOME=$S/stage/xdg_$TAG MESA_SHADER_CACHE_DIR=$S/mesa_stage_$TAG nice -n ${NICE:-10} timeout 4500 \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tests/race/run_stage.gd -- --graphics=modern --gfx-preset=${STAGE_PRESET:-low} --stage=kiel_hamburg --from=kiel \
	--vehicle=limousine --hour=21 --weather=rain --seed=11 --timescale=${STAGE_TS:-16} --max-seconds=${STAGE_MAX:-4000} > "$S/stage/$TAG.log" 2>&1
echo "exit=$? wall=$(( $(date +%s) - T0 ))" >> "$S/stage/$TAG.log"
rm -rf "$S/stage/xdg_$TAG"
grep -a "ERGEBNIS\|exit=\|SCRIPT ERROR\|SHADER ERROR" "$S/stage/$TAG.log" | cut -c1-300
