#!/bin/bash
# clips after the A/B queue: two 30-s A/B clips on the head (Kiel – Hamburg into the fuel stop at km 15, Saragossa – Pau
# through the mountain bends), and the stop-and-go clip (a start from the countdown: standing, driving off) at "Mittel"
# on the head and on the base (note 5, NACH-R7c NR7c-01)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
O=$S/clips
mkdir -p $O
: # (chain2 runs clips after the A/B queue)
F="--autopilot --traffic-warmup --no-countdown"
clip() {   # clip <tree> <name> <preset> <seconds> <args…>
	local tree=$1 name=$2 preset=$3 secs=$4; shift 4
	local wt=$W
	[ "$tree" = base ] && wt=$S/base
	t0=$SECONDS
	(cd $wt && CLIP_S=$secs FPS=30 GFX_ARGS="--gfx-preset=$preset" CLIP_TIMEOUT=5400 nice -n 10 tools/ab_clip.sh $O/$name.mp4 "$@" > $O/$name.log 2>&1)
	echo "$(date +%H:%M:%S) clip $name exit=$? $((SECONDS - t0)) s"
}
[ -s $O/kiel_hamburg_tankstopp.mp4 ] || clip head kiel_hamburg_tankstopp high 30 --stage=kiel_hamburg --from=kiel --start-km=8 --hour=12 --weather=normal --vehicle=limousine \
	--seed=11 $F --autopilot-refuel=always --start-speed=130
[ -s $O/saragossa_pau_kurven.mp4 ] || clip head saragossa_pau_kurven high 30 --stage=saragossa_pau --from=saragossa --start-km=170 --hour=11 --weather=normal --vehicle=kompakt \
	--seed=4 $F --autopilot-refuel=never --start-speed=80
for t in head base; do
	[ -s $O/anfahren_mittel_$t.mp4 ] || clip $t anfahren_mittel_$t medium 12 --stage=nuernberg_fulda --from=nuernberg --start-km=0 --hour=12 --weather=normal \
		--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup
done
echo "QUEUE-CLIPS DONE $(date +%T)"
