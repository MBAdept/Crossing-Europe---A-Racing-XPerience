#!/bin/bash
# rc_one.sh <log> <check file res path> [args after --] : one render check under Xvfb, XDG/Mesa in scratch
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
W=${W:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4}
LOG=$1; F=$2; shift 2
export XDG_DATA_HOME=$S/xdg/rc
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export TMPDIR=$S/tmp
mkdir -p $XDG_DATA_HOME $MESA_SHADER_CACHE_DIR $TMPDIR
cd $W
t0=$SECONDS
nice -n 10 timeout ${TO:-1800} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $F -- --graphics=modern --gfx-sync --audio-sync "$@" > $LOG 2>&1
c=$?
echo "exit=$c $((SECONDS-t0))s" >> $LOG
grep -E "RENDER-CHECK|SCRIPT ERROR|SHADER ERROR|exit=" $LOG | tail -20
