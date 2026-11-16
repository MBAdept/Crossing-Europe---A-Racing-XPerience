#!/usr/bin/env bash
# QA-R5 queue 3 (after queue 2): gates. One heavy job at a time.
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-4
while ! grep -q QUEUE2_DONE $Q/queue2.log 2>/dev/null; do sleep 30; done
mkdir -p $Q/logs $Q/tmp
export MESA_SHADER_CACHE_DIR=$Q/mesa
step() { echo "== $1 $(date +%T)"; }
step run_tests
X=$(mktemp -d $Q/tmp/xdg_rt.XXXXXX)
(cd $WT && XDG_DATA_HOME=$X nice -n 10 timeout 3600 tools/run_tests.sh > $Q/logs/run_tests_full.log 2>&1; echo "run_tests exit $?")
rm -rf $X
tail -25 $Q/logs/run_tests_full.log
step render_checks
X=$(mktemp -d $Q/tmp/xdg_rc.XXXXXX)
for f in tunnel_bridge start_km0 terrain_cover light_base; do
	(cd $WT && XDG_DATA_HOME=$X nice -n 10 tools/run_render_checks.sh modern $f > $Q/logs/render_$f.log 2>&1; echo "render $f exit $?")
	grep -E "RENDER-CHECK|FEHLER|SCRIPT ERROR" $Q/logs/render_$f.log | head -20
done
rm -rf $X
step golden
X=$(mktemp -d $Q/tmp/xdg_go.XXXXXX)
(cd $WT && XDG_DATA_HOME=$X nice -n 10 timeout 5400 tools/golden.sh check > $Q/logs/golden_check.log 2>&1; echo "golden exit $?")
rm -rf $X
grep -E "GOLDEN" $Q/logs/golden_check.log
echo "QUEUE3_DONE $(date +%T)"
