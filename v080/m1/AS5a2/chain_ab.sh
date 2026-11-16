#!/usr/bin/env bash
# AS5a2: A/B Arcade|Modern at the city arrivals of batch 2 (after chain_meas), then the 10-s clip.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a2
source $S/env.sh
if [ -z "${NOWAIT:-}" ]; then
	until grep -q "=== chain_meas fertig" $S/logs/chain_meas.out 2>/dev/null; do sleep 30; done
fi
echo "start $(date +%H:%M)"
A=$S/ab
mkdir -p $A
for n in ${AB_NAMES:-pa am br tl}; do
	$S/tools/ab_all.sh $A $n high "12 22"
	$S/tools/ab_all.sh $A $n medium "19.5"
done
$S/tools/ab_all.sh $A be high "12"
if [ -z "${NOCLIP:-}" ]; then
	cd $WT
	waitmem
	CLIP_S=10 FPS=60 SIDE=960x540 GFX_ARGS="--gfx-preset=high" MESA_SHADER_CACHE_DIR=$S/mesa nice -n 19 tools/ab_clip.sh \
		"$D/fahrt_paris_50kmh.mp4" --stage=luettich_paris --from=luettich --start-km=${CLIP_KM:-387.6} --hour=12 \
		--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown \
		--start-speed=50 > "$S/logs/clip.log" 2>&1
	echo "clip exit $? $(date +%H:%M)"
fi
echo "=== chain_ab fertig $(date +%H:%M)"
