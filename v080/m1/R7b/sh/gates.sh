#!/usr/bin/env bash
# R7b gates on the worktree head, one heavy step at a time (nice 10). gates.sh <step...>
#   steps: import scripts tests golden modern render sight path perf
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-2
G=$S/gates
mkdir -p $G $S/xdg_gates
export XDG_DATA_HOME=$S/xdg_gates
export MESA_SHADER_CACHE_DIR=$S/mesa
export TMPDIR=$S/tmp
guard() { while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done; }
cd $WT
for step in "$@"; do
	guard
	T0=$(date +%s)
	case $step in
	import) nice -n 10 timeout 900 godot --headless --path . --import > $G/import.log 2>&1; echo "import exit $? errors $(grep -ciE 'error' $G/import.log)" ;;
	scripts) nice -n 10 timeout 600 godot --headless --path . -s res://tests/check_scripts.gd > $G/check_scripts.log 2>&1; echo "scripts exit $?: $(grep -E 'geprüft' $G/check_scripts.log)" ;;
	tests) nice -n 10 tools/run_tests.sh > $G/run_tests.log 2>&1; echo "run_tests exit $?: $(tail -3 $G/run_tests.log | tr '\n' ' ')" ;;
	tests_filter) nice -n 10 tools/run_tests.sh "${FILTER}" > $G/run_tests_${FILTER}.log 2>&1; echo "run_tests $FILTER exit $?: $(tail -3 $G/run_tests_${FILTER}.log | tr '\n' ' ')" ;;
	golden) nice -n 10 tools/golden.sh check > $G/golden.log 2>&1; echo "golden exit $?: $(grep -E 'identisch|FEHLER|verschieden' $G/golden.log | tail -4 | tr '\n' ' ')" ;;
	modern) nice -n 10 tools/golden.sh modern-check > $G/modern_check.log 2>&1; echo "modern-check exit $?: $(tail -4 $G/modern_check.log | tr '\n' ' ')" ;;
	render) nice -n 10 tools/run_render_checks.sh all > $G/render_checks.log 2>&1; echo "render exit $?: $(grep -c 'RENDER-CHECK-DATEI.* OK' $G/render_checks.log) OK, $(grep -cE 'RENDER-CHECK-DATEI.*(FEHLER|ZEITLIMIT)' $G/render_checks.log) failed" ;;
	sight) nice -n 10 timeout 7200 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $G/modern_sight_full.log 2>&1; echo "sight exit $?: $(grep -E '^CHECK' $G/modern_sight_full.log | tr '\n' ' ' | cut -c1-600)" ;;
	path) nice -n 10 timeout 7200 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $G/modern_path_full.log 2>&1; echo "path exit $?: $(grep -E '^CHECK' $G/modern_path_full.log | tr '\n' ' ' | cut -c1-600)" ;;
	perf)
		: > $G/perf.log
		for tree in head base; do
			T=$WT
			[ "$tree" = base ] && T=$S/base
			for spec in "kiel_hamburg:kiel:12:medium" "dresden_leipzig:dresden:15:medium"; do
				IFS=: read -r stg frm hr pre <<< "$spec"
				guard
				(cd "$T" && nice -n 10 timeout 7200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
					--audio-driver Dummy --resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=$stg --from=$frm \
					--hour=$hr --weather=normal --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=$pre \
					> "$G/perf_${tree}_${stg}_${pre}.log" 2>&1)
				echo "perf $tree $stg $pre exit $? ($(grep -cE 'SCRIPT ERROR|Parse Error|SHADER ERROR' "$G/perf_${tree}_${stg}_${pre}.log") Skriptfehler)" >> $G/perf.log
				grep -E '^PERF|^RUN' "$G/perf_${tree}_${stg}_${pre}.log" >> $G/perf.log
			done
		done
		echo "perf: $(grep -E '^perf' $G/perf.log | tr '\n' ' ')" ;;
	esac
	echo "   ($step: $(( $(date +%s) - T0 )) s, $(date -u +%H:%M))"
done
