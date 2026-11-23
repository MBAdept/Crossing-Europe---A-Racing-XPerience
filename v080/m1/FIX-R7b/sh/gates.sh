#!/usr/bin/env bash
# FIX-R7b: the remaining gates, one heavy job at a time (logs in m1/FIX-R7b/gates/). Skips what has a finished log.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-6
B=$S/base
G=$S/gates
mkdir -p $G
export MESA_SHADER_CACHE_DIR=$S/mesa
guard() { while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done; }
fresh() { rm -rf "$1"; mkdir -p "$1"; }
cd $W
for step in ${STEPS:-modern sight path perf render}; do
	guard
	case $step in
	modern)
		grep -q "GOLDEN modern" $G/golden_modern.log 2>/dev/null && continue
		fresh $S/xdg_gm
		XDG_DATA_HOME=$S/xdg_gm nice -n 10 tools/golden.sh modern-check > $G/golden_modern.log 2>&1
		echo "modern-check rc=$?"
		;;
	sight)
		grep -q "Tests bestanden\|CHECKS OK\|OK" $G/modern_sight_full.log 2>/dev/null && grep -q "modern_sight_model" $G/modern_sight_full.log && continue
		fresh $S/xdg_sight
		XDG_DATA_HOME=$S/xdg_sight nice -n 10 timeout 3600 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $G/modern_sight_full.log 2>&1
		echo "sight rc=$?"
		;;
	path)
		grep -q "CHECK" $G/modern_path_check_full.log 2>/dev/null && continue
		fresh $S/xdg_path
		XDG_DATA_HOME=$S/xdg_path nice -n 10 timeout 3600 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $G/modern_path_check_full.log 2>&1
		echo "path rc=$?"
		;;
	perf)
		for stage in ${PERF_STAGES:-kiel_hamburg:kiel}; do
			IFS=: read -r st from <<<"$stage"
			for tree in head base; do
				dir=$W
				[ $tree = base ] && dir=$B
				f=$G/perf_${tree}_${st}_deck_${HOUR:-12}.log
				[ -s $f ] && grep -q '^PERF' $f && continue
				guard
				fresh $S/xdg_perf_$tree
				(cd $dir && XDG_DATA_HOME=$S/xdg_perf_$tree nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . \
					--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=$st \
					--from=$from --seed=7 --timescale=40 --hour=${HOUR:-12} --graphics=modern --gfx-preset=deck > $f 2>&1)
				echo "perf $tree $st rc=$? $(grep -c 'SCRIPT ERROR' $f) script errors"
			done
		done
		;;
	render)
		grep -q "Render-Prüfdateien in Ordnung" $G/render_all.log 2>/dev/null && continue
		fresh $S/xdg_rall
		XDG_DATA_HOME=$S/xdg_rall nice -n 10 tools/run_render_checks.sh all > $G/render_all.log 2>&1
		echo "render all rc=$?"
		;;
	esac
done
echo GATES_DONE
