#!/bin/bash
# rt.sh <log name> [filter] : tools/run_tests.sh with own absolute XDG
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
L=$1; shift
export XDG_DATA_HOME=$S/xdg/rt_$L
mkdir -p $XDG_DATA_HOME
cd $W
t0=$SECONDS
nice -n 10 tools/run_tests.sh "$@" > $S/logs/rt_$L.log 2>&1
c=$?
echo "exit=$c $((SECONDS-t0))s" >> $S/logs/rt_$L.log
tail -6 $S/logs/rt_$L.log
