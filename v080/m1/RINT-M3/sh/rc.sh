#!/bin/bash
# rc.sh <log name> <check file res path> [args after --] : one render check under Xvfb
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
L=$1; F=$2; shift 2
export XDG_DATA_HOME=$S/xdg/rc
mkdir -p $XDG_DATA_HOME
cd $W
t0=$SECONDS
nice -n 10 timeout ${TO:-1800} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $F -- --graphics=modern --gfx-sync --audio-sync "$@" > $S/logs/$L.log 2>&1
c=$?
echo "exit=$c $((SECONDS-t0))s" >> $S/logs/$L.log
grep -E "RENDER-CHECK|SCRIPT ERROR|SHADER ERROR|exit=" $S/logs/$L.log | tail -25
