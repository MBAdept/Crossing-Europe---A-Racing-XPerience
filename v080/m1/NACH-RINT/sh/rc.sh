#!/bin/bash
# rc.sh <filter> : tools/run_render_checks.sh modern <filter> in the head worktree
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT/sh/env.sh
cd $HEAD_W
export XDG_DATA_HOME=$S/xdg/rc
mkdir -p $XDG_DATA_HOME
t0=$SECONDS
nice -n 10 tools/run_render_checks.sh modern "$1" > $S/logs/rc_$1.full.log 2>&1
echo "rc $1 rc=$? $((SECONDS-t0))s"
grep -E "RENDER-CHECK|SCRIPT ERROR|SHADER ERROR|Too many instances" $S/logs/rc_$1.full.log | cut -c1-700
