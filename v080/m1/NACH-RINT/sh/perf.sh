#!/bin/bash
# perf.sh <name> <tree> <gfx> <preset> <stage> <hour> <weather> <seed> <ts> <shot-km list or -> : stage_shots.gd run
# (modern under Xvfb, arcade headless), log $S/perf/<name>.log, pictures $S/perf/<name>_km*.png, summary on stdout.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-RINT/sh/env.sh
name=$1 tree=$2 gfx=$3 preset=$4 stage=$5 hour=$6 weather=$7 seed=$8 ts=$9 shots=${10} extra=${11:-} maxs=${MAXS:-3300}
mkdir -p $S/perf
home=$S/xdg/perf_$name
rm -rf "$home"; mkdir -p "$home"
export XDG_DATA_HOME=$home
SH=()
[ "$shots" != "-" ] && SH=(--shot-km=$shots --out=$S/perf/$name)
cd $tree
t0=$SECONDS
if [ "$gfx" = arcade ]; then
  nice -n 10 timeout 3600 godot --headless --path . -s $S/sh/stage_shots.gd -- --stage=$stage --hour=$hour --weather=$weather \
    --seed=$seed --autopilot-refuel=auto --timescale=$ts --max-seconds=3300 --graphics=arcade > $S/perf/$name.log 2>&1
else
  nice -n 10 timeout 3600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
    --resolution 1280x720 -s $S/sh/stage_shots.gd -- --stage=$stage --hour=$hour --weather=$weather --seed=$seed \
    --autopilot-refuel=auto --timescale=$ts --max-seconds=$maxs --graphics=modern --gfx-preset=$preset $extra "${SH[@]}" > $S/perf/$name.log 2>&1
fi
echo "perf $name rc=$? $((SECONDS-t0))s"
grep -E '^(HASHES|RUN |ERRORS|  (WARN|ERR|MSGERR))' $S/perf/$name.log | cut -c1-400
python3 $S/sh/perfsum.py $S/perf/$name.log
