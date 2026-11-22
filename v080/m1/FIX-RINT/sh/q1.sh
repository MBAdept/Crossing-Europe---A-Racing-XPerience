#!/bin/bash
# queue 1: wait for the F-01 reshoot, then TS15N Modern (station night), then check_night spielerauto
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
while pgrep -f "f01_fix/valik" > /dev/null; do sleep 5; done
echo "q1: TS15N start $(date +%T)"
GFX_ARGS=--gfx-preset=high $S/sh/mshot.sh $S/shots/ts15n_v1/TS15N --stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-km=14.3 --hour=21 --weather=normal --start-speed=100 --shot-times=1.5,2.5
echo "q1: spielerauto start $(date +%T)"
$S/sh/rc_one.sh $S/logs/rc_night_car1.log res://tests/race3d/render/check_night.gd --only=spielerauto --save=$S/shots/night_car1
echo "q1: done $(date +%T)"
