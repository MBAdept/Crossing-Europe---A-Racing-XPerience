#!/usr/bin/env bash
# FIX-R6 first look: DEV border (B-01 masts) by day and night, DEV finish and start gantry (B-03) by day and night.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
O=$S/shots
B="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
for h in 12 21; do
	$S/bin/shot.sh $O/grenze_$h $B --hour=$h --start-km=64.3 --start-speed=100 --shot-times=0.8,1.4,2.0 > $O/grenze_$h.out 2>&1
	echo "grenze_$h exit $?"
	$S/bin/shot.sh $O/ziel_$h $B --hour=$h --start-km=129.4 --start-speed=50 --shot-times=1,2.5 > $O/ziel_$h.out 2>&1
	echo "ziel_$h exit $?"
done
B2="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
for h in 12 21; do
	$S/bin/shot.sh $O/start_$h $B2 --hour=$h --start-km=0 --shot-times=1,3.6 > $O/start_$h.out 2>&1
	echo "start_$h exit $?"
done
