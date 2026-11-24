#!/bin/bash
# R7D clips: two 20-s A/B clips on the head – the open motorway by day (Kiel – Hamburg km 25, into a concrete section)
# and at dusk (km 40) – resumable
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
O=$S/clips
mkdir -p $O
F="--autopilot --traffic-warmup --no-countdown"
clip() {   # clip <name> <preset> <seconds> <args…>
	local name=$1 preset=$2 secs=$3; shift 3
	t0=$SECONDS
	(cd $W && CLIP_S=$secs FPS=30 GFX_ARGS="--gfx-preset=$preset" CLIP_TIMEOUT=5400 nice -n 10 tools/ab_clip.sh $O/$name.mp4 "$@" > $O/$name.log 2>&1)
	echo "$(date +%H:%M:%S) clip $name exit=$? $((SECONDS - t0)) s"
}
[ -s $O/freie_strecke_tag.mp4 ] || clip freie_strecke_tag high 20 --stage=kiel_hamburg --from=kiel --start-km=22 --hour=12 --weather=normal \
	--vehicle=limousine --seed=11 $F --autopilot-refuel=never --start-speed=140
[ -s $O/freie_strecke_daemmerung.mp4 ] || clip freie_strecke_daemmerung high 20 --stage=kiel_hamburg --from=kiel --start-km=40 --hour=19.5 \
	--weather=normal --vehicle=limousine --seed=11 $F --autopilot-refuel=never --start-speed=140
echo "QUEUE-CLIPS DONE $(date +%T)"
