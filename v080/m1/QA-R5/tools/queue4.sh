#!/usr/bin/env bash
# QA-R5 queue 4 (after queue 3): Steam Deck pictures, micro benchmark, perf runs. One heavy job at a time.
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4
while ! grep -q QUEUE3_DONE $Q/queue3.log 2>/dev/null; do sleep 30; done
mkdir -p $Q/logs $Q/tmp
export MESA_SHADER_CACHE_DIR=$Q/mesa
step() { echo "== $1 $(date +%T)"; }
step retest
# the three failures of the full run, each alone, on the R5 head and on the base
for tree in $WT $Q/base; do
	tag=$([ "$tree" = "$WT" ] && echo r5 || echo base)
	X=$(mktemp -d $Q/tmp/xdg_rt2.XXXXXX)
	(cd $tree && XDG_DATA_HOME=$X nice -n 10 timeout 300 godot --headless --path . -s res://tests/race/check_attract.gd -- --graphics=modern > $Q/logs/retest_attract_$tag.log 2>&1; echo "attract $tag exit $?")
	grep -E "CHECK idle|CHECKS" $Q/logs/retest_attract_$tag.log
	for f in test_engine3_checks test_music_checks; do
		(cd $tree && XDG_DATA_HOME=$X nice -n 10 timeout 600 godot --headless --path . -s res://tests/run_tests.gd -- --filter=$f > $Q/logs/retest_${f}_$tag.log 2>&1; echo "$f $tag exit $?")
		grep -E "Tests, |^FAIL" $Q/logs/retest_${f}_$tag.log
	done
	rm -rf $X
done
step deck
PRESET=deck SCREEN=1280x800 SUFFIX=_deck bash $Q/tools/shots.sh new kb_nacht u1_innen kb_rampe
PRESET=deck SCREEN=1280x800 SUFFIX=_deck bash $Q/tools/shots.sh base kb_nacht
step bench
X=$(mktemp -d $Q/tmp/xdg_b.XXXXXX)
(cd $Q/mut && XDG_DATA_HOME=$X nice -n 10 timeout 1800 godot --headless --path . -s res://tests/qa_r5/bench_r5.gd > $Q/logs/bench_r5.log 2>&1; echo "bench r5 exit $?")
(cd $Q/base && XDG_DATA_HOME=$X nice -n 10 timeout 1800 godot --headless --path . -s res://tests/qa_r5/bench_r5.gd > $Q/logs/bench_base.log 2>&1; echo "bench base exit $?")
rm -rf $X
grep -E "BENCH-SUM|SCRIPT ERROR" $Q/logs/bench_r5.log $Q/logs/bench_base.log
step perf
perf() {   # perf <name> <tree> <args…>
	local name=$1 tree=$2
	shift 2
	local X
	X=$(mktemp -d $Q/tmp/xdg_p.XXXXXX)
	(cd $tree && XDG_DATA_HOME=$X nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- "$@" --graphics=modern --gfx-preset=deck \
		> $Q/logs/perf_$name.log 2>&1; echo "perf $name exit $?")
	rm -rf $X
	grep -E "^PERF|^RUN|SCRIPT ERROR|SHADER ERROR" $Q/logs/perf_$name.log | cut -c1-300
}
KH="--stage=kiel_hamburg --from=kiel --start-km=76 --vehicle=limousine --hour=12 --weather=normal --seed=11 --timescale=4 --max-seconds=1200 --autopilot-refuel=never"
U1="--stage=bern_mailand --from=bern --start-km=183 --vehicle=limousine --hour=12 --weather=normal --seed=16 --timescale=4 --max-seconds=600 --autopilot-refuel=never"
perf kh_r5 $WT $KH
perf kh_base $Q/base $KH
perf u1_r5 $WT $U1
perf u1_base $Q/base $U1
echo "QUEUE4_DONE $(date +%T)"
