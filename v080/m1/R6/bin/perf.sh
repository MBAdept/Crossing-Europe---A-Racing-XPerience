#!/usr/bin/env bash
# R6: a whole Modern autopilot run of the test stage (every structure of R6: start, fuel stations, radar, border,
# City Limits, finish) at night under Xvfb, with perf_stats. Usage: perf.sh <name> <project folder>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
NAME=$1
PROJ=$2
NICE=19
if [ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
	NICE=10
fi
mkdir -p "$S/xdg/perf_$NAME"
export XDG_DATA_HOME=$S/xdg/perf_$NAME
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$PROJ" || exit 1
nice -n "$NICE" godot --headless --path . --import > "$S/perf_${NAME}_import.log" 2>&1
echo "import exit $?"
nice -n "$NICE" timeout 7200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=dev_testetappe --from=dev_start --hour=21 --weather=normal \
	--vehicle=limousine --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=${PRESET:-medium} > "$S/perf_$NAME.log" 2>&1
echo "run exit $?"
grep -E "^(PERF|RUN |ERGEBNIS|FEHLER)|SCRIPT ERROR" "$S/perf_$NAME.log"
