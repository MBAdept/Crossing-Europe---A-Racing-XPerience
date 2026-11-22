#!/bin/bash
# R7a: whole Modern autopilot stage Kiel – Hamburg with perf_stats – this tree, then the base (same machine, alone).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
export TMPDIR=$S/tmp
echo "$(date -u +%H:%M:%S) start load $(cut -d' ' -f1-3 /proc/loadavg)"
bash "$S/sh/stage.sh" kh_mine mine modern medium kiel_hamburg kiel 12 normal 40
echo "$(date -u +%H:%M:%S) load $(cut -d' ' -f1-3 /proc/loadavg)"
bash "$S/sh/stage.sh" kh_base base modern medium kiel_hamburg kiel 12 normal 40
echo "$(date -u +%H:%M:%S) done load $(cut -d' ' -f1-3 /proc/loadavg)"
