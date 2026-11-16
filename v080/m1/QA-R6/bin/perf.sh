#!/usr/bin/env bash
# QA-R6: whole Modern autopilot run of DEV at 21:00 under Xvfb with perf_stats (draw calls, commits, render()).
# usage: PRESET=deck perf.sh <name> <project dir>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
NAME=$1
PROJ=$2
mkdir -p "$S/xdg/perf_$NAME" $S/perf
export XDG_DATA_HOME=$S/xdg/perf_$NAME
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$PROJ" || exit 1
nice -n 10 timeout 7000 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=dev_testetappe --from=dev_start --hour=21 --weather=normal \
	--vehicle=limousine --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=${PRESET:-deck} > "$S/perf/$NAME.log" 2>&1
echo "run exit $?" >> "$S/perf/$NAME.log"
