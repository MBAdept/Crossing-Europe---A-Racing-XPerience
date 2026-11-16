#!/bin/bash
# rc.sh <base|head> <filter> [logname] – tools/run_render_checks.sh modern <filter> (nice 10, own XDG/MESA)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WHICH=$1; F=$2; NAME=${3:-$2}
if [ "$WHICH" = base ]; then WT=$S/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7; fi
mkdir -p $S/rc $S/xdg/rc_${WHICH}_$NAME
cd "$WT" || exit 2
t0=$SECONDS
XDG_DATA_HOME=$S/xdg/rc_${WHICH}_$NAME MESA_SHADER_CACHE_DIR=$S/mesa_$WHICH nice -n 10 tools/run_render_checks.sh modern "$F" > $S/rc/${WHICH}_$NAME.log 2>&1
echo "rc $WHICH $NAME exit=$? $((SECONDS-t0))s"
grep -E "RENDER-CHECK|FEHLER|SCRIPT ERROR|SHADER ERROR" $S/rc/${WHICH}_$NAME.log | cut -c1-400
