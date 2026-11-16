#!/bin/bash
# chain A: gates on the head worktree, one heavy job at a time
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-2
cd $W || exit 9
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p $S/mesa $S/gates $S/xdg
stamp() { echo "$(date +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg) $*" >> $S/gates/chain_a.txt; }
stamp start
rm -rf $S/xdg/rt; mkdir -p $S/xdg/rt
XDG_DATA_HOME=$S/xdg/rt nice -n 10 tools/run_tests.sh > $S/gates/run_tests_full.log 2>&1; stamp "run_tests exit $?"
rm -rf $S/xdg/sight; mkdir -p $S/xdg/sight
XDG_DATA_HOME=$S/xdg/sight nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $S/gates/sight_full.log 2>&1; stamp "sight exit $?"
XDG_DATA_HOME=$S/xdg/sight nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $S/gates/path_full.log 2>&1; stamp "path exit $?"
for f in structures start_km0 light_base terrain_cover; do
  rm -rf $S/xdg/rc_$f; mkdir -p $S/xdg/rc_$f
  XDG_DATA_HOME=$S/xdg/rc_$f RENDER_CHECK_TIMEOUT=2400 nice -n 10 tools/run_render_checks.sh modern $f > $S/gates/rc_$f.log 2>&1; stamp "rc $f exit $?"
done
stamp done
