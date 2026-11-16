#!/bin/bash
# stage.sh <tag> <tree> – whole Modern autopilot stage under Xvfb (Kiel – Hamburg, 21 Uhr, Regen; default „Niedrig“, Zeitraffer 16)
# log in stage/<tag>.log; run one after the other for the head and the base checkout
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
TAG=$1
TREE=$2
N=${NICE:-19}
mkdir -p "$R4/stage"
rm -rf "$R4/stage/xdg_$TAG"
mkdir -p "$R4/stage/xdg_$TAG"
cd "$TREE" || exit 2
T0=$(date +%s)
XDG_DATA_HOME=$R4/stage/xdg_$TAG MESA_SHADER_CACHE_DIR=$R4/mesa_stage_$TAG nice -n $N timeout 4500 \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tests/race/run_stage.gd -- --graphics=modern --gfx-preset=${STAGE_PRESET:-low} --stage=kiel_hamburg --from=kiel \
	--vehicle=limousine --hour=21 --weather=rain --seed=11 --timescale=${STAGE_TS:-16} --max-seconds=${STAGE_MAX:-4000} > "$R4/stage/$TAG.log" 2>&1
echo "exit=$? wall=$(( $(date +%s) - T0 ))" >> "$R4/stage/$TAG.log"
rm -rf "$R4/stage/xdg_$TAG"
grep -a "ERGEBNIS\|exit=\|SCRIPT ERROR\|SHADER ERROR" "$R4/stage/$TAG.log" | cut -c1-300
