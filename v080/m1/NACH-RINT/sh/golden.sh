#!/bin/bash
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT/sh/env.sh
cd $HEAD_W
export XDG_DATA_HOME=$S/xdg/golden
mkdir -p $XDG_DATA_HOME
t0=$SECONDS
nice -n 10 tools/golden.sh check > $S/logs/golden_check.full.log 2>&1
echo "golden check rc=$? $((SECONDS-t0))s"
grep -E "^GOLDEN|ANDERS|FEHL" $S/logs/golden_check.full.log | head -30
