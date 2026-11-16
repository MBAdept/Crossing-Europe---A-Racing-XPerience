#!/bin/bash
# FIX-M2 B-06: player paint in the vehicle probe (scene player_nobrake), Arcade and the merged tree (FIX-M2 + R4).
#   b06.sh <modern tag prefix>   (Arcade pictures only when missing)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2
L=$S/logs/b06.log
PFX=${1:-p_mt}
for spec in "limousine 12 normal" "sportwagen 19.5 normal" "kompakt 22 snow" "gran_turismo 16 rain"; do
	set -- $spec
	v=$1 h=$2 w=$3
	if [ ! -f "$S/shots/veh/p_arc_${v}_player_nobrake.png" ]; then
		$S/sh/veh.sh arcade "p_arc_${v}" --hour=$h --weather=$w --vehicle=$v --only=player_nobrake >> $L 2>&1
	fi
	$S/sh/veh_mt.sh modern "${PFX}_${v}" --hour=$h --weather=$w --vehicle=$v --gfx-preset=medium --only=player_nobrake >> $L 2>&1
done
echo "$(date -u +%T) B06-DONE ${PFX}" >> $L
