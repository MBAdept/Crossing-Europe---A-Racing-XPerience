#!/usr/bin/env bash
# AS5aR2: A/B at the city arrivals (high + medium, noon / dusk / 22:00) and the 50 km/h clip through Paris
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
$S/ab_all.sh $S/ab "${RUNS:-pa:high:22 pa:high:12 be:high:22 am:high:12 ly_out:high:12 hh:high:22 br:medium:19.5 pa:medium:19.5}"
if [ -z "${NOCLIP:-}" ]; then
	waitmem
	mkdir -p $S/clip
	CLIP_S=10 FPS=60 SIDE=960x540 GFX_ARGS="--gfx-preset=high" nice -n 19 tools/ab_clip.sh \
		"$S/clip/fahrt_paris_50kmh.mp4" --stage=luettich_paris --from=luettich --start-km=387.6 --hour=12 \
		--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-target=50 --autopilot-refuel=never \
		--no-countdown --start-speed=50 > "$S/logs/clip.log" 2>&1
	echo "clip exit $? $(date +%H:%M)"
fi
echo "=== chain_ab fertig $(date +%H:%M)"
