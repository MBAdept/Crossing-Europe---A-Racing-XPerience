#!/usr/bin/env bash
# R7b: the whole render queue, detached (the tool's background limit of 2 h would cut it): first batch (resumed),
# Belgrade/Dortmund redo and clips, near views, Madrid night redo, gates.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7b
echo "master start $(date -u +%H:%M)"
while pgrep -f "sh/batch_ab.sh" > /dev/null; do sleep 20; done
grep -q BATCH_DONE $S/batch.log || $S/sh/batch_ab.sh >> $S/batch.log 2>&1
echo "batch1 done $(date -u +%H:%M)"
rm -f $S/batch2.log $S/batch3.log
$S/sh/batch2.sh > $S/batch2.log 2>&1
echo "batch2 done $(date -u +%H:%M)"
$S/sh/batch3.sh > $S/batch3.log 2>&1
echo "batch3 done $(date -u +%H:%M)"
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
GFX_ARGS="--gfx-preset=high" $S/sh/ab.sh "$D/ab/madrid_22" --stage=burgos_madrid --from=burgos --start-km=228.0 --hour=22 $COMMON 2>&1 | tail -2
echo "madrid redo done $(date -u +%H:%M)"
$S/sh/gates.sh import scripts tests golden modern render sight path perf > $S/gates.log 2>&1
echo "MASTER_DONE $(date -u +%H:%M)"
