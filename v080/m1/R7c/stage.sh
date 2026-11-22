#!/usr/bin/env bash
# R7c: a whole autopilot stage under Xvfb (tests/race/run_stage.gd) – ERGEBNIS, PERF, RUN.
#   stage.sh <tag> <preset> <stage> <from> <hour> [timescale]   (BASE=1: my files from the base 43a1fcc for the run)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
TAG=$1; PRESET=$2; STAGE=$3; FROM=$4; HOUR=$5; TS=${6:-40}
cd "$WT"
FILES="assets/shaders/modern/baked.gdshader assets/shaders/modern/leaves.gdshader assets/shaders/modern/billboard.gdshader scripts/race3d/builders/props.gd scripts/race3d/prop_library.gd scripts/race3d/modern_materials.gd scripts/race3d/model_factory.gd config/game_config.json"
if [ "${BASE:-0}" = "1" ]; then
	echo "BASE-CHECKOUT $(date +%H:%M)" >> "$S/STAND.md"
	git checkout 43a1fcc -- $FILES
fi
mkdir -p "$S/stage"
x=$S/xdg/stage_$TAG
rm -rf "$x"; mkdir -p "$x"
waitmem
T0=$(date +%s)
XDG_DATA_HOME=$x MESA_SHADER_CACHE_DIR=$S/mesa_stage nice -n 10 timeout ${STAGE_TO:-5400} \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
	-s res://tests/race/run_stage.gd -- --graphics=modern --gfx-preset=$PRESET --stage=$STAGE --from=$FROM \
	--vehicle=limousine --hour=$HOUR --weather=normal --seed=11 --timescale=$TS --max-seconds=${STAGE_MAX:-5000} > "$S/stage/$TAG.log" 2>&1
echo "exit=$? wall=$(( $(date +%s) - T0 ))" >> "$S/stage/$TAG.log"
if [ "${BASE:-0}" = "1" ]; then
	git checkout HEAD -- $FILES
	sed -i '/^BASE-CHECKOUT/d' "$S/STAND.md"
fi
rm -rf "$x"
echo "$(date +%H:%M) stage $TAG: $(grep -a -c 'SCRIPT ERROR\|SHADER ERROR' $S/stage/$TAG.log) Fehlerzeilen, $(tail -1 $S/stage/$TAG.log)"
