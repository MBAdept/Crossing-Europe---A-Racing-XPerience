#!/bin/bash
# rcd.sh <base|head> <file.gd> <name> [extra args after --] – one render check directly, pictures kept in rc/pics_<which>_<name>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WHICH=$1; F=$2; NAME=$3; shift 3
if [ "$WHICH" = base ]; then WT=$S/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7; fi
P=$S/rc/pics_${WHICH}_$NAME
mkdir -p $S/rc $P $S/xdg/rcd_${WHICH}_$NAME
cd "$WT" || exit 2
t0=$SECONDS
XDG_DATA_HOME=$S/xdg/rcd_${WHICH}_$NAME MESA_SHADER_CACHE_DIR=$S/mesa_$WHICH nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 60 -s res://tests/race3d/render/$F -- --graphics=modern --gfx-sync --audio-sync --save=$P "$@" \
  > $S/rc/d_${WHICH}_$NAME.log 2>&1
echo "rcd $WHICH $NAME exit=$? $((SECONDS-t0))s"
grep -E "RENDER-CHECK|FEHLER|SCRIPT ERROR|SHADER ERROR" $S/rc/d_${WHICH}_$NAME.log | cut -c1-500
