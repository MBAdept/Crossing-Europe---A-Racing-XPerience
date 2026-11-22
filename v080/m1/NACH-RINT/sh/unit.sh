#!/bin/bash
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT/sh/env.sh
cd $HEAD_W
export XDG_DATA_HOME=$S/xdg/unit
mkdir -p $XDG_DATA_HOME
t0=$SECONDS
nice -n 10 tools/run_tests.sh unit/race3d > $S/logs/unit_race3d.log 2>&1; echo "unit/race3d rc=$? $((SECONDS-t0))s"
tail -15 $S/logs/unit_race3d.log
