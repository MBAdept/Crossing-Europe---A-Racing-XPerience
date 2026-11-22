#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4
export XDG_DATA_HOME=$S/xdg/rt_filter
export MESA_SHADER_CACHE_DIR=$S/mesa
export TMPDIR=$S/tmp
export LP_NUM_THREADS=2
mkdir -p $XDG_DATA_HOME $TMPDIR
cd $W
for f in check_light_cap check_benchmark check_attract flare lights chunk_streamer; do
  echo "=== $f $(date +%T)"
  nice -n 10 tools/run_tests.sh $f 2>&1 | tail -15
done
echo "q10 done $(date +%T)"
