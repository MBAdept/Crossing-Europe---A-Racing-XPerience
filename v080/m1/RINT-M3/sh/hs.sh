#!/bin/bash
# hs.sh <log name> <res path of -s script> [args after --]: one headless script run with own XDG
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
L=$1; F=$2; shift 2
export XDG_DATA_HOME=$S/xdg/hs
mkdir -p $XDG_DATA_HOME
cd $W
t0=$SECONDS
nice -n 10 timeout ${TO:-1800} godot --headless --path . -s $F -- "$@" > $S/logs/$L.log 2>&1
c=$?
echo "exit=$c $((SECONDS-t0))s" >> $S/logs/$L.log
grep -E "^CHECK|SCRIPT ERROR|Parse Error|FEHLER|exit=" $S/logs/$L.log | tail -25
