#!/bin/bash
# R7a: a whole autopilot stage under Xvfb (tests/race/run_stage.gd) – ERGEBNIS, PERF, RUN (after RINT-M2's stage.sh).
#   stage.sh <tag> <mine|base> <mode> <preset> <stage> <from> <hour> <weather> [timescale]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
TAG=$1; TREE=$2; MODE=$3; PRESET=$4; STAGE=$5; FROM=$6; HOUR=$7; WEATHER=$8; TS=${9:-40}
T=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
[ "$TREE" = base ] && T=$S/base
mkdir -p "$S/stage" "$S/mesa_stage"
x=$S/xdg/stage_$TAG
rm -rf "$x"; mkdir -p "$x"
while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
cd "$T" || exit 2
T0=$(date +%s)
XDG_DATA_HOME=$x MESA_SHADER_CACHE_DIR=$S/mesa_stage LP_NUM_THREADS=2 nice -n 10 timeout 5400 \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
	-s res://tests/race/run_stage.gd -- --graphics=$MODE --gfx-preset=$PRESET --stage=$STAGE --from=$FROM \
	--vehicle=limousine --hour=$HOUR --weather=$WEATHER --seed=7 --timescale=$TS --max-seconds=${MAXS:-5000} > "$S/stage/$TAG.log" 2>&1
echo "exit=$? wall=$(( $(date +%s) - T0 ))" >> "$S/stage/$TAG.log"
rm -rf "$x"
echo "$(date -u +%H:%M:%S) stage $TAG: $(grep -a -c 'SCRIPT ERROR\|SHADER ERROR' $S/stage/$TAG.log) Fehlerzeilen, $(tail -1 $S/stage/$TAG.log)"
