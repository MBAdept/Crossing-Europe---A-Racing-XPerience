#!/bin/bash
# FIX-R7c: the pictures the findings point to, from this tree (tag fix), side by side with QA-R7c's Arcade and R7c
# (bd1803b) pictures of the same simulation state (bit-identical repro checked): $D/<name>_tri_NN.jpg
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
TAG=${TAG:-fix}
declare -A POS
POS[pa]="--stage=luettich_paris --from=luettich --start-km=387.5"
POS[hh]="--stage=kiel_hamburg --from=kiel --start-km=88.2"
POS[nu]="--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.0"
POS[am]="--stage=bremen_amsterdam --from=bremen --start-km=357.3"
one() {   # one <name> <preset> <hour>
	local n=$1 q=$2 h=$3
	local scr=1280x720
	[ "$q" = "deck" ] && scr=1280x800
	local name=${n}_${q}_h${h}
	if ! ls "$S/shots/${name}_${TAG}"_[0-9][0-9].png > /dev/null 2>&1; then
		# shellcheck disable=SC2086
		SCREEN=$scr "$S/sh/shot.sh" "$name" "$TAG" "$q" ${POS[$n]} --hour=$h --weather=normal --vehicle=limousine --seed=11 \
			--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=2,4
	fi
	tri "$name"
}
start() {   # the countdown at Nürnberg – Fulda km 0 (QR7c-06)
	local q=$1
	local name=start_nu_${q}_h12
	if ! ls "$S/shots/${name}_${TAG}"_[0-9][0-9].png > /dev/null 2>&1; then
		local scr=1280x720
		[ "$q" = "deck" ] && scr=1280x800
		SCREEN=$scr "$S/sh/shot.sh" "$name" "$TAG" "$q" --stage=nuernberg_fulda --from=nuernberg --start-km=0 --hour=12 \
			--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5
	fi
	tri "$name"
}
tri() {
	local name=$1
	for f in "$S/shots/${name}_${TAG}"_[0-9][0-9].png; do
		[ -s "$f" ] || continue
		local nn=${f##*_}
		nn=${nn%.png}
		local a="$Q/${name}_arcade_${nn}.png"
		local r="$Q/${name}_r7c_${nn}.png"
		[ -s "$a" ] && [ -s "$r" ] || continue
		convert \( "$a" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "Arcade" \) \
			\( "$r" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "R7c bd1803b" \) \
			\( "$f" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "FIX-R7c" \) \
			-background '#10182c' +smush 6 -resize 2400x -quality 88 "$D/${name}_tri_${nn}.jpg"
		compare -metric AE -fuzz 15% "$r" "$f" null: 2> "$S/shots/${name}_${nn}_ae.txt"
		echo "$name $nn: $(cat "$S/shots/${name}_${nn}_ae.txt") px anders als R7c (fuzz 15 %)" >> "$S/logs/pics.out"
	done
}
for job in "$@"; do
	case "$job" in
	start_*) start "${job#start_}" ;;
	*) IFS=: read -r n q h <<< "$job"; one "$n" "$q" "$h" ;;
	esac
done
echo "PICS DONE $*" >> "$S/logs/pics.out"
