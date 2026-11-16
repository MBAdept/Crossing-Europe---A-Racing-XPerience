#!/usr/bin/env bash
# QA-R5 queue 5 (after queue 4): draw counters with the last frame on the bridge deck / in the tube (deck preset), and
# the music check of the R5 head once more alone.
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4
while ! grep -q QUEUE4_DONE $Q/queue4.log 2>/dev/null; do sleep 30; done
export MESA_SHADER_CACHE_DIR=$Q/mesa
perf() {   # perf <name> <tree> <args…>
	local name=$1 tree=$2
	shift 2
	local X
	X=$(mktemp -d $Q/tmp/xdg_p.XXXXXX)
	(cd $tree && XDG_DATA_HOME=$X nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- "$@" --graphics=modern --gfx-preset=deck \
		> $Q/logs/perf_$name.log 2>&1; echo "perf $name exit $?")
	rm -rf $X
}
KB="--stage=kiel_hamburg --from=kiel --start-km=78.3 --vehicle=limousine --hour=12 --weather=normal --seed=11 --timescale=1 --max-seconds=110 --autopilot-refuel=never"
UI="--stage=bern_mailand --from=bern --start-km=188 --vehicle=limousine --hour=12 --weather=normal --seed=16 --timescale=1 --max-seconds=110 --autopilot-refuel=never"
perf kbdeck_r5 $WT $KB
perf kbdeck_base $Q/base $KB
perf u1deck_r5 $WT $UI
perf u1deck_base $Q/base $UI
X=$(mktemp -d $Q/tmp/xdg_m.XXXXXX)
(cd $WT && XDG_DATA_HOME=$X nice -n 10 timeout 600 godot --headless --path . -s res://tests/run_tests.gd -- --filter=test_music_checks > $Q/logs/retest2_music_r5.log 2>&1; echo "music r5 again exit $?")
grep -E "Tests, |^FAIL" $Q/logs/retest2_music_r5.log
rm -rf $X
echo "QUEUE5_DONE $(date +%T)"
