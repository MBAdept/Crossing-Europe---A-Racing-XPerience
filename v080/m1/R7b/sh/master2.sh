#!/usr/bin/env bash
# R7b: second half of the queue, gates first (a failing gate needs a fix before the last pictures):
# waits for batch2 (Paris clip), then gates, near views, Madrid and Dortmund night redo.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7b
echo "master2 start $(date -u +%H:%M)"
while pgrep -f "sh/batch2.sh" > /dev/null; do sleep 20; done
echo "batch2 done $(date -u +%H:%M)"
$S/sh/gates.sh import scripts tests golden modern render sight path perf > $S/gates.log 2>&1
echo "GATES_DONE $(date -u +%H:%M)"
rm -f $S/batch3.log
$S/sh/batch3.sh > $S/batch3.log 2>&1
echo "batch3 done $(date -u +%H:%M)"
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
GFX_ARGS="--gfx-preset=high" $S/sh/ab.sh "$D/ab/madrid_22" --stage=burgos_madrid --from=burgos --start-km=228.0 --hour=22 $COMMON 2>&1 | tail -2
GFX_ARGS="--gfx-preset=high" $S/sh/ab.sh "$D/ab/dortmund_22" --stage=bremen_dortmund --from=bremen --start-km=225.0 --hour=22 $COMMON 2>&1 | tail -2
echo "MASTER2_DONE $(date -u +%H:%M)"
