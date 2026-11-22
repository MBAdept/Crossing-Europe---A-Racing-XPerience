#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
while pgrep -f "sh/q3.sh" > /dev/null; do sleep 5; done
echo "q5: sportwagen 2 start $(date +%T)"
$S/sh/rc_one.sh $S/logs/rc_night_sw2.log res://tests/race3d/render/check_night.gd --only=spielerauto --fall=Sportwagen --save=$S/shots/night_sw2
echo "q5: TS15N v3 start $(date +%T)"
GFX_ARGS=--gfx-preset=high $S/sh/mshot.sh $S/shots/ts15n_v3/TS15N --stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-km=14.3 --hour=21 --weather=normal --start-speed=100 --shot-times=1.5,2.5
echo "q5: done $(date +%T)"
