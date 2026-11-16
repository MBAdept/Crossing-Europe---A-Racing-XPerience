#!/usr/bin/env bash
# NACH-R6: head pictures (Arcade | Modern 2b7dcc0). Skips pictures already made (restartable).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
O=$S/shots
mkdir -p $O
DEV="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
DEVC="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
WP="--stage=wien_prag --from=prag --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
run() {
	local name=$1; shift
	if ls "$O/${name}"_ab_*.jpg >/dev/null 2>&1; then echo "skip $name"; return; fi
	local t0=$(date +%s)
	$S/bin/shot.sh "$O/$name" "$@" > "$O/$name.out" 2>&1
	echo "$name exit $? $(( $(date +%s) - t0 )) s"
}
run grenze_12 $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=0.8,1.4,2.0
run grenze_21 $DEV --hour=21 --start-km=64.3 --start-speed=100 --shot-times=1.4,2.0
run ziel_12 $DEV --hour=12 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run ziel_21 $DEV --hour=21 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run start_21 $DEVC --hour=21 --start-km=0 --shot-times=1,3.6
run tank_21 $DEV --hour=21 --start-km=18.5 --start-speed=100 --shot-times=1.2,2.6
run wp_grenze_12 $WP --hour=12 --start-km=269.4 --start-speed=100 --shot-times=0.8,1.4,2.0
