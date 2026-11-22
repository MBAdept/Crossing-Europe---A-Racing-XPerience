#!/bin/bash
# R7a: the perf pair again with a warm shader cache (first pair: this tree ran first with a cold cache), base first.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
export TMPDIR=$S/tmp
echo "$(date -u +%H:%M:%S) start load $(cut -d' ' -f1-3 /proc/loadavg)"
bash "$S/sh/stage.sh" kh_base2 base modern medium kiel_hamburg kiel 12 normal 40
echo "$(date -u +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg)"
bash "$S/sh/stage.sh" kh_mine2 mine modern medium kiel_hamburg kiel 12 normal 40
echo "$(date -u +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg)"
MAXS=420 bash "$S/sh/stage.sh" kh_mine_ts4 mine modern medium kiel_hamburg kiel 12 normal 4
echo "$(date -u +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg)"
MAXS=420 bash "$S/sh/stage.sh" kh_base_ts4 base modern medium kiel_hamburg kiel 12 normal 4
echo "$(date -u +%H:%M:%S) done load $(cut -d' ' -f1-3 /proc/loadavg)"
