#!/usr/bin/env bash
# FIX-R6 second batch: station by night/day (shop pool), border after the stay order and the night fascia, KH fuel stop,
# city at night, KH start/finish, the border Nürnberg -> Prag, three deck pictures. Skips pictures already made.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
O=$S/shots
mkdir -p $O
DEV="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
KHC="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
PN="--stage=prag_nuernberg --from=nuernberg --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
run() {
	local name=$1; shift
	if ls "$O/${name}"_ab_*.jpg >/dev/null 2>&1; then echo "skip $name"; return; fi
	local t0=$(date +%s)
	$S/bin/shot.sh "$O/$name" "$@" > "$O/$name.out" 2>&1
	echo "$name exit $? $(( $(date +%s) - t0 )) s"
}
run tank_21 $DEV --hour=21 --start-km=18.5 --start-speed=100 --shot-times=1.2,2.6,3.3
run grenze2_12 $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=1.4,2.0
run grenze2_21 $DEV --hour=21 --start-km=64.3 --start-speed=100 --shot-times=1.4,2.0
run tank_12 $DEV --hour=12 --start-km=18.5 --start-speed=100 --shot-times=1.2,2.6,3.3
run kh_tank_12 $KH --hour=12 --start-km=13.4 --start-speed=100 --shot-times=0.8,1.6,2.4
run kh_tank_21 $KH --hour=21 --start-km=13.4 --start-speed=100 --shot-times=0.8,1.6,2.4
run stadt_21 $DEV --hour=21 --start-km=111 --start-speed=50 --shot-times=1.5,3
run kh_stadt_21 $KH --hour=21 --start-km=76 --start-speed=50 --shot-times=1,3
run kh_start_12 $KHC --hour=12 --start-km=0 --shot-times=1,3.6
run kh_ziel_12 $KH --hour=12 --start-km=94.2 --start-speed=100 --shot-times=1,1.8
run pn_grenze_15 $PN --hour=15 --start-km=129.3 --start-speed=100 --shot-times=1.0,1.8
export GFX_ARGS="--gfx-preset=deck" SCREEN=1280x800
run deck_tank_21 $DEV --hour=21 --start-km=19.1 --start-speed=100 --shot-times=1.0
run deck_grenze_12 $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=1.2
run deck_ziel_21 $DEV --hour=21 --start-km=129.4 --start-speed=50 --shot-times=2.5
