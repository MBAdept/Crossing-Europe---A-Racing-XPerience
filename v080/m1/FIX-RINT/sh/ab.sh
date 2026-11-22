#!/bin/bash
# ab.sh <out_prefix> [ab_shot args...] : tools/ab_shot.sh of the FIX-RINT worktree, TMPDIR/Mesa cache in scratch
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
W=${W:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4}
export TMPDIR=$S/tmp
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export XDG_DATA_HOME=$S/xdg/ab
mkdir -p $TMPDIR $MESA_SHADER_CACHE_DIR $XDG_DATA_HOME "$(dirname $1)"
cd $W
t0=$SECONDS
nice -n 10 tools/ab_shot.sh "$@" > $1.tool.log 2>&1
c=$?
echo "exit=$c $((SECONDS-t0))s" >> $1.tool.log
tail -3 $1.tool.log
