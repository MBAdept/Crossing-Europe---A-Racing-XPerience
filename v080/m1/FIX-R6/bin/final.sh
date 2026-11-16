#!/usr/bin/env bash
# FIX-R6 final steps: Modern change detectors renewed (the start gantry changed on purpose), the real-time music test
# alone, a second head/base performance pair.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3
G=$S/gates
export MESA_SHADER_CACHE_DIR=$S/mesa
stamp() { echo "$(date +%H:%M:%S) $* (load $(cut -d' ' -f1 /proc/loadavg))" >> $G/status_final.txt; }
cd $W || exit 1
stamp "start modern_make"
rm -rf $S/xdg/g_mmake; mkdir -p $S/xdg/g_mmake $G/modern_make_keep
XDG_DATA_HOME=$S/xdg/g_mmake KEEP=$G/modern_make_keep nice -n 10 tools/golden.sh modern-make > $G/modern_make.log 2>&1
echo "exit $?" >> $G/modern_make.log
stamp "done modern_make"
stamp "start music"
rm -rf $S/xdg/g_music; mkdir -p $S/xdg/g_music
XDG_DATA_HOME=$S/xdg/g_music nice -n 10 tools/run_tests.sh test_music_checks > $G/music_alone.log 2>&1
echo "exit $?" >> $G/music_alone.log
stamp "done music"
for run in head2 base2; do
	stamp "start perf $run"
	dir=$W
	[ "$run" = base2 ] && dir=$S/base
	rm -rf $S/xdg/perf_$run; mkdir -p $S/xdg/perf_$run
	(cd $dir && XDG_DATA_HOME=$S/xdg/perf_$run nice -n 10 timeout 7000 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=dev_testetappe --from=dev_start --hour=21 \
		--weather=normal --vehicle=limousine --seed=7 --timescale=40 --max-seconds=7000 --graphics=modern --gfx-preset=deck > $S/perf/${run}_deck.log 2>&1
	echo "run exit $?" >> $S/perf/${run}_deck.log)
	stamp "done perf $run"
done
stamp "final end"
