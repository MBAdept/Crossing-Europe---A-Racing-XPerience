#!/usr/bin/env bash
# R6: the rest of the A/B pictures (DEV by day and at night, Kiel – Hamburg fuel stop at night, a real border, city
# arrival at night, Steam-Deck preset).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
O=$S/shots
SHOT=$S/bin/shot.sh
DEV="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
run() { local name=$1; shift; echo "== $name $(date +%H:%M)"; "$SHOT" "$O/$name" "$@" > "$O/$name.out" 2>&1; echo "   exit $? $(tail -1 "$O/$name.out")"; }
run v3_station_night $DEV --hour=21 --start-km=19.1 --start-speed=100 --shot-times=0.4,1.0,1.6
run v3_border_day $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=0.5,1.2,1.9
run v3_border_night $DEV --hour=21 --start-km=64.3 --start-speed=100 --shot-times=0.5,1.2,1.9
run v3_kh_pylon $KH --no-countdown --hour=12 --start-km=13.25 --start-speed=100 --shot-times=0.4,0.9
run v3_kh_pylon_night $KH --no-countdown --hour=21 --start-km=13.25 --start-speed=100 --shot-times=0.4,0.9
run v3_station_day $DEV --hour=12 --start-km=19.1 --start-speed=100 --shot-times=0.4,1.0,1.6
run v3_radar_night $DEV --hour=21 --start-km=11.8 --start-speed=150 --autopilot-speeding --shot-times=0.45,0.55,0.7
run v3_city_day $DEV --hour=12 --start-km=111 --start-speed=50 --shot-times=1,3
run v3_dev_start_night $DEV --hour=21 --start-km=0 --shot-times=1,3.6
run v3_dev_finish_night $DEV --hour=21 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run v3_kh_station_night $KH --no-countdown --hour=21 --start-km=13.6 --start-speed=120 --shot-times=1.5,3
run v3_kh_city_night $KH --no-countdown --hour=21 --start-km=76 --start-speed=50 --shot-times=1,3
run v3_border_prag_nuernberg --stage=prag_nuernberg --from=prag --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --hour=15 --start-km=159.3 --start-speed=100 --shot-times=0.6,1.4,2.2
GFX_ARGS="--gfx-preset=deck" SCREEN=1280x800 run v3_deck_station_night $DEV --hour=21 --start-km=19.1 --start-speed=100 --shot-times=1.0
GFX_ARGS="--gfx-preset=deck" SCREEN=1280x800 run v3_deck_border_day $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=1.2
GFX_ARGS="--gfx-preset=deck" SCREEN=1280x800 run v3_deck_city_night $DEV --hour=21 --start-km=111 --start-speed=50 --shot-times=2
echo DONE $(date +%H:%M)
