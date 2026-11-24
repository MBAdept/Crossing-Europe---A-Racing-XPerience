#!/bin/bash
# perf.sh <name> <head|base> <preset> <stage> <hour> <weather> <seed> <ts> [extra…] : stage_shots.gd Modern run under
# Xvfb (threaded streaming, no --gfx-sync), log $S/perf/<name>.log, summary on stdout (NACH-RINT's tools)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
name=$1 tree=$2 preset=$3 stage=$4 hour=$5 weather=$6 seed=$7 ts=$8; shift 8
case "$tree" in base) WT=$S/base ;; *) WT=$W ;; esac
mkdir -p $S/perf
home=$S/xdg/perf_$name
rm -rf "$home"; mkdir -p "$home"
export XDG_DATA_HOME=$home
cd $WT
t0=$SECONDS
nice -n 10 timeout ${PERF_TO:-3600} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 1280x720 -s $S/sh/stage_shots.gd -- --stage=$stage --hour=$hour --weather=$weather --seed=$seed \
  --autopilot-refuel=auto --timescale=$ts --max-seconds=${MAXS:-3300} --graphics=modern --gfx-preset=$preset "$@" > $S/perf/$name.log 2>&1
echo "perf $name rc=$? $((SECONDS-t0))s"
grep -E '^(HASHES|RUN |ERRORS)' $S/perf/$name.log | cut -c1-300
python3 $S/sh/perfsum.py $S/perf/$name.log
