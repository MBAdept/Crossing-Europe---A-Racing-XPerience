#!/bin/bash
# NACH-R7a queue 2 (head 4a43944): golden check, modern_sight --full, modern_path_check --full, render checks of the
# touched areas, run_tests.sh complete (once)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-11
Q1=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/tasks/bn0tn2g8d.output
until grep -q "queue1 done" "$Q1" 2>/dev/null; do sleep 20; done
memwait() { while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done; }
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
cd "$WT" || exit 1
echo "$(date -u +%H:%M:%S) start queue2"
memwait
mkdir -p $S/xdg/gold $S/gold_keep
XDG_DATA_HOME=$S/xdg/gold KEEP=$S/gold_keep nice -n 10 tools/golden.sh check > $S/logs/gate_golden.log 2>&1
echo "$(date -u +%H:%M:%S) golden exit=$? $(grep 'GOLDEN' $S/logs/gate_golden.log | tr '\n' ' ')"
memwait
mkdir -p $S/xdg/sight
XDG_DATA_HOME=$S/xdg/sight nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $S/logs/gate_sight_full.log 2>&1
echo "$(date -u +%H:%M:%S) sight exit=$? $(grep -c 'CHECK .* OK' $S/logs/gate_sight_full.log) OK, $(grep -c 'FEHLER' $S/logs/gate_sight_full.log) FEHLER"
memwait
XDG_DATA_HOME=$S/xdg/sight nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $S/logs/gate_path_full.log 2>&1
echo "$(date -u +%H:%M:%S) path exit=$? $(grep 'CHECK' $S/logs/gate_path_full.log | tr '\n' ' ')"
for f in terrain_cover start_km0 light_base structures; do
	memwait
	mkdir -p $S/xdg/rc_$f
	XDG_DATA_HOME=$S/xdg/rc_$f nice -n 10 tools/run_render_checks.sh modern $f > $S/logs/gate_rc_$f.log 2>&1
	echo "$(date -u +%H:%M:%S) render $f exit=$? $(grep 'RENDER-CHECK-DATEI' $S/logs/gate_rc_$f.log | tr '\n' ' ')"
done
memwait
mkdir -p $S/xdg/rt
XDG_DATA_HOME=$S/xdg/rt nice -n 10 tools/run_tests.sh > $S/logs/gate_run_tests.log 2>&1
echo "$(date -u +%H:%M:%S) run_tests exit=$? $(tail -3 $S/logs/gate_run_tests.log | tr '\n' ' ')"
echo "$(date -u +%H:%M:%S) queue2 done"
