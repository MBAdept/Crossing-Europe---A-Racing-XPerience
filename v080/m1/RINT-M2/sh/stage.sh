#!/bin/bash
# RINT-M2: a whole autopilot stage under Xvfb (tests/race/run_stage.gd) – ERGEBNIS, PERF, RUN.
#   stage.sh <tag> <tree: base|merged|A..H|path> <mode arcade|modern> <preset> <stage> <from> <hour> <weather> [timescale] [extra...]
#   -> stage/<tag>.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
TAG=$1; TREE=$2; MODE=$3; PRESET=$4; STAGE=$5; FROM=$6; HOUR=$7; WEATHER=$8; TS=${9:-16}
shift 9 2> /dev/null
case "$TREE" in
merged) T=$S/merged ;;
base) T=$S/snap_base ;;
[A-H]) T=$S/snap_$TREE ;;
*) T=$TREE ;;
esac
mkdir -p "$S/stage"
x=$S/xdg/stage_$TAG
rm -rf "$x"; mkdir -p "$x"
cd "$T" || exit 2
T0=$(date +%s)
XDG_DATA_HOME=$x MESA_SHADER_CACHE_DIR=$S/mesa_stage nice -n 10 timeout ${STAGE_TO:-5400} \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
	-s res://tests/race/run_stage.gd -- --graphics=$MODE --gfx-preset=$PRESET --stage=$STAGE --from=$FROM \
	--vehicle=limousine --hour=$HOUR --weather=$WEATHER --seed=11 --timescale=$TS --max-seconds=${STAGE_MAX:-5000} "$@" > "$S/stage/$TAG.log" 2>&1
echo "exit=$? wall=$(( $(date +%s) - T0 ))" >> "$S/stage/$TAG.log"
rm -rf "$x"
echo "$(date -u +%H:%M:%S) stage $TAG: $(grep -a -c 'SCRIPT ERROR\|SHADER ERROR' $S/stage/$TAG.log) Fehlerzeilen, $(tail -1 $S/stage/$TAG.log)"
grep -a "^ERGEBNIS" "$S/stage/$TAG.log" | cut -c1-300
