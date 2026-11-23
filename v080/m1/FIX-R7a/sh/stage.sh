#!/bin/bash
# FIX-R7a: autopilot stage run under Xvfb (tests/race/run_stage.gd) – ERGEBNIS, PERF, RUN lines.
#   stage.sh <tag> <head|base> <preset> <stage> <from> <hour> <weather> <timescale> <start_km> [max_s]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a
TAG=$1; TREE=$2; PRESET=$3; STAGE=$4; FROM=$5; HOUR=$6; WEATHER=$7; TS=$8; KM=$9; MAXS=${10:-3000}
T=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-8
[ "$TREE" = base ] && T=$S/base
mkdir -p "$S/stage" "$S/mesa_stage"
x=$S/xdg/stage_$TAG
rm -rf "$x"; mkdir -p "$x"
while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
cd "$T" || exit 2
T0=$(date +%s)
echo "load before: $(cut -d' ' -f1-3 /proc/loadavg)" > "$S/stage/$TAG.log"
XDG_DATA_HOME=$x MESA_SHADER_CACHE_DIR=$S/mesa_stage LP_NUM_THREADS=2 nice -n 10 timeout 3600 \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
	-s res://tests/race/run_stage.gd -- --graphics=modern --gfx-preset=$PRESET --stage=$STAGE --from=$FROM \
	--vehicle=limousine --hour=$HOUR --weather=$WEATHER --seed=7 --timescale=$TS --start-km=$KM --max-seconds=$MAXS >> "$S/stage/$TAG.log" 2>&1
echo "exit=$? wall=$(( $(date +%s) - T0 )) load after: $(cut -d' ' -f1-3 /proc/loadavg)" >> "$S/stage/$TAG.log"
rm -rf "$x"
echo "$(date -u +%H:%M:%S) stage $TAG: $(grep -a -c 'SCRIPT ERROR\|SHADER ERROR' $S/stage/$TAG.log) Fehlerzeilen, $(tail -1 $S/stage/$TAG.log)"
