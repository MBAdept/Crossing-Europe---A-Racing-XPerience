#!/usr/bin/env bash
# R7c: the two A/B clips at "Mittel" (20 s, 30 fps, AVIs kept for the frame-by-frame look)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
cd "$WT"
mkdir -p "$S/clips"
export CLIP_S=20 FPS=30 SIDE=960x540 KEEP_AVI=1 GFX_ARGS="--gfx-preset=medium"
for c in ${CLIPS:-paris nuernberg}; do
	waitmem
	st=$(date +%s)
	case $c in
	paris) A="--stage=luettich_paris --from=luettich --start-km=386.8" ;;
	nuernberg) A="--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=101.6" ;;
	esac
	nice -n 10 tools/ab_clip.sh "$S/clips/${PREFIX:-}$c.mp4" $A --hour=12 --weather=normal --vehicle=limousine --seed=11 \
		--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=60 > "$S/clips/${PREFIX:-}$c.log" 2>&1
	echo "CLIP $c exit $? $(( $(date +%s) - st )) s $(date +%H:%M)"
done
