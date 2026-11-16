#!/usr/bin/env bash
# R6: first look at every element (A/B, Modern "Hoch").
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
O=$S/shots
SHOT=$S/bin/shot.sh
DEV="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
run() { local name=$1; shift; echo "== $name"; "$SHOT" "$O/$name" "$@" > "$O/$name.out" 2>&1; echo "   exit $? $(tail -1 "$O/$name.out")"; }
run v2_start $KH --hour=12 --start-km=0 --shot-times=1,3.6,5.2
run v2_border_day $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=0.5,1.2,1.9
run v2_border_night $DEV --hour=21 --start-km=64.3 --start-speed=100 --shot-times=0.5,1.2,1.9
run v2_station_night $DEV --hour=21 --start-km=19.1 --start-speed=100 --shot-times=0.4,1.0,1.6
run v2_radar_day $DEV --hour=12 --start-km=11.8 --start-speed=150 --autopilot-speeding --shot-times=0.45,0.55,0.7
run v2_city_night $DEV --hour=21 --start-km=111 --start-speed=50 --shot-times=1,3
run v2_finish $KH --hour=12 --no-countdown --start-km=94 --start-speed=120 --shot-times=1,2.4
echo DONE
