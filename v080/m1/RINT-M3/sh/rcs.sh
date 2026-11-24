#!/bin/bash
# rcs.sh <log name> <mode> [filter] : tools/run_render_checks.sh
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
L=$1; shift
export XDG_DATA_HOME=$S/xdg/rcs
mkdir -p $XDG_DATA_HOME
cd $W
t0=$SECONDS
nice -n 10 tools/run_render_checks.sh "$@" > $S/logs/rcs_$L.log 2>&1
c=$?
echo "exit=$c $((SECONDS-t0))s" >> $S/logs/rcs_$L.log
grep -E "RENDER-CHECK-DATEI|FEHLER|SCRIPT ERROR|exit=" $S/logs/rcs_$L.log | tail -40
