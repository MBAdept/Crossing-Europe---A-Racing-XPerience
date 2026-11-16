#!/bin/bash
# FIX-M2: merged tree (FIX-M2 f45268e + origin/wip/v080-r4) – import, then S1/C1/N1 Modern high and the night vehicle rows
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2
L=$S/logs/mt_queue.log
cd $S/mt
echo "$(date -u +%T) import" >> $L
XDG_DATA_HOME=$S/xdg/mtimp nice -n 10 timeout 1800 godot --headless --path . --import > $S/logs/mt_import.log 2>&1
echo "$(date -u +%T) import exit $?" >> $L
mkdir -p $S/shots/mt
for P in S1 C1 N1; do
	A=$($S/sh/pos.sh $P)
	GFX="--gfx-preset=high" $S/sh/shot_mt.sh modern $S/shots/mt/${P}_mthigh $A --shot-times=3 >> $L 2>&1
	GFX="--gfx-preset=high" $S/sh/shot.sh modern $S/shots/mt/${P}_fxhigh $A --shot-times=3 >> $L 2>&1
done
$S/sh/veh_mt.sh modern mt_h22 --hour=22 --gfx-preset=medium --only=d20,d60 >> $L 2>&1
$S/sh/veh_mt.sh modern mt_h12 --hour=12 --gfx-preset=medium --only=d20,d60 >> $L 2>&1
echo "$(date -u +%T) MT-DONE" >> $L
