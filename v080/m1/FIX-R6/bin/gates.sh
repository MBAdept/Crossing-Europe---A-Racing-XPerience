#!/usr/bin/env bash
# FIX-R6 gates on the head of the worktree, one after the other at nice 10; each step logs into gates/ and appends a line
# to gates/status.txt. Steps already finished (status line "done <step>") are skipped, so the chain can be restarted.
#   gates.sh [step…]   (default: all steps in order)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3
G=$S/gates
mkdir -p $G $S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
STEPS=${*:-"import scripts tests golden sight collect modern_check render perf_head perf_base"}
stamp() { echo "$(date +%H:%M:%S) $*" >> $G/status.txt; }
done_already() { grep -q "^.* done $1\$" $G/status.txt 2>/dev/null; }
cd $W || exit 1
for st in $STEPS; do
	if done_already $st; then continue; fi
	stamp "start $st (load $(cut -d' ' -f1 /proc/loadavg))"
	case $st in
	import)
		XDG_DATA_HOME=$S/xdg/g_import nice -n 10 godot --headless --path . --import > $G/import.log 2>&1
		echo "exit $?" >> $G/import.log ;;
	scripts)
		XDG_DATA_HOME=$S/xdg/g_scripts nice -n 10 godot --headless --path . -s res://tests/check_scripts.gd > $G/check_scripts.log 2>&1
		echo "exit $?" >> $G/check_scripts.log ;;
	tests)
		rm -rf $S/xdg/g_tests; mkdir -p $S/xdg/g_tests
		XDG_DATA_HOME=$S/xdg/g_tests nice -n 10 tools/run_tests.sh > $G/run_tests.log 2>&1
		echo "exit $?" >> $G/run_tests.log ;;
	golden)
		rm -rf $S/xdg/g_golden; mkdir -p $S/xdg/g_golden
		XDG_DATA_HOME=$S/xdg/g_golden nice -n 10 tools/golden.sh check > $G/golden_check.log 2>&1
		echo "exit $?" >> $G/golden_check.log ;;
	sight)
		XDG_DATA_HOME=$S/xdg/g_sight nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $G/modern_sight.log 2>&1
		echo "exit $?" >> $G/modern_sight.log
		XDG_DATA_HOME=$S/xdg/g_sight nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $G/modern_path.log 2>&1
		echo "exit $?" >> $G/modern_path.log ;;
	collect)
		XDG_DATA_HOME=$S/xdg/g_collect nice -n 10 godot --headless --path . -s $S/bin/collect_time.gd -- --only=dev_testetappe,kiel_hamburg,prag_nuernberg > $G/collect_head.log 2>&1
		echo "exit $?" >> $G/collect_head.log
		(cd $S/base && XDG_DATA_HOME=$S/xdg/g_collect nice -n 10 godot --headless --path . -s $S/bin/collect_time.gd -- --only=dev_testetappe,kiel_hamburg,prag_nuernberg > $G/collect_base.log 2>&1; echo "exit $?" >> $G/collect_base.log) ;;
	modern_check)
		rm -rf $S/xdg/g_mcheck $G/modern_keep; mkdir -p $S/xdg/g_mcheck $G/modern_keep
		XDG_DATA_HOME=$S/xdg/g_mcheck KEEP=$G/modern_keep nice -n 10 tools/golden.sh modern-check > $G/modern_check.log 2>&1
		echo "exit $?" >> $G/modern_check.log ;;
	render)
		rm -rf $S/xdg/g_render; mkdir -p $S/xdg/g_render
		export RENDER_CHECK_TIMEOUT=2400
		XDG_DATA_HOME=$S/xdg/g_render nice -n 10 tools/run_render_checks.sh arcade > $G/render_arcade.log 2>&1
		echo "exit $?" >> $G/render_arcade.log
		for f in tests/race3d/render/check_*.gd; do
			n=$(basename $f .gd); n=${n#check_}
			if grep -q "RENDER-CHECK-DATEI .*check_$n.gd " $G/render_modern_all.log 2>/dev/null; then continue; fi
			XDG_DATA_HOME=$S/xdg/g_render nice -n 10 tools/run_render_checks.sh modern "check_$n.gd" > $G/render_$n.log 2>&1
			echo "exit $?" >> $G/render_$n.log
			grep "RENDER-CHECK-DATEI" $G/render_$n.log >> $G/render_modern_all.log
		done ;;
	perf_head)
		rm -rf $S/xdg/perf_head; mkdir -p $S/xdg/perf_head $S/perf
		XDG_DATA_HOME=$S/xdg/perf_head nice -n 10 timeout 7000 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 \
			--audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=dev_testetappe --from=dev_start --hour=21 \
			--weather=normal --vehicle=limousine --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=deck > $S/perf/head_deck.log 2>&1
		echo "run exit $?" >> $S/perf/head_deck.log ;;
	perf_base)
		rm -rf $S/xdg/perf_base; mkdir -p $S/xdg/perf_base $S/perf
		(cd $S/base && XDG_DATA_HOME=$S/xdg/perf_base nice -n 10 godot --headless --path . --import > $S/perf/base_import.log 2>&1; XDG_DATA_HOME=$S/xdg/perf_base nice -n 10 timeout 7000 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 \
			--audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=dev_testetappe --from=dev_start --hour=21 \
			--weather=normal --vehicle=limousine --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=deck > $S/perf/base_deck.log 2>&1
		echo "run exit $?" >> $S/perf/base_deck.log) ;;
	esac
	stamp "done $st"
done
stamp "chain end"
