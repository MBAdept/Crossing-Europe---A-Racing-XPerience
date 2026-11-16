#!/usr/bin/env bash
# NACH-R6: base pictures (Modern with the c8b18d1 builders) for the same settings as shots_head.sh, then the head
# builders back. Restartable: skips pictures already made. Builds triptychs Arcade | Modern base | Modern head.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
O=$S/shots
DEV="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
DEVC="--stage=dev_testetappe --from=dev_start --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup"
WP="--stage=wien_prag --from=prag --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
$S/bin/swap.sh base
run() {
	local name=$1; shift
	if ls "$O/base_${name}"_modern_*.png >/dev/null 2>&1; then echo "skip $name"; return; fi
	local t0=$(date +%s)
	$S/bin/mshot.sh "$O/base_$name" "$@" > "$O/base_$name.out" 2>&1
	echo "base_$name exit $? $(( $(date +%s) - t0 )) s"
}
run grenze_12 $DEV --hour=12 --start-km=64.3 --start-speed=100 --shot-times=0.8,1.4,2.0
run grenze_21 $DEV --hour=21 --start-km=64.3 --start-speed=100 --shot-times=1.4,2.0
run ziel_12 $DEV --hour=12 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run ziel_21 $DEV --hour=21 --start-km=129.4 --start-speed=50 --shot-times=1,2.5
run start_21 $DEVC --hour=21 --start-km=0 --shot-times=1,3.6
run tank_21 $DEV --hour=21 --start-km=18.5 --start-speed=100 --shot-times=1.2,2.6
run wp_grenze_12 $WP --hour=12 --start-km=269.4 --start-speed=100 --shot-times=0.8,1.4,2.0
$S/bin/swap.sh head
for a in "$O"/*_arcade_[0-9][0-9].png; do
	n=$(basename "$a")
	name=${n%_arcade_*}
	nn=${n##*_}; nn=${nn%.png}
	b="$O/base_${name}_modern_${nn}.png"; h="$O/${name}_modern_${nn}.png"
	[ -s "$b" ] && [ -s "$h" ] || continue
	convert \( "$a" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade" \) \
		\( "$b" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern Basis c8b18d1" \) \
		\( "$h" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern FIX-R6 2b7dcc0" \) \
		-background '#10182c' +smush 6 -resize 50% -quality 88 "$O/tri_${name}_${nn}.jpg"
	echo "$O/tri_${name}_${nn}.jpg"
done
