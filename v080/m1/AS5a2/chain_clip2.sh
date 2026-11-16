#!/usr/bin/env bash
# AS5a2: the 10-s clip again, this time held at 50 km/h (--autopilot-target=50), after chain_final.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a2
source $S/env.sh
until grep -q "=== chain_final fertig" $S/logs/chain_final.out 2>/dev/null; do sleep 30; done
cd $WT
waitmem
mkdir -p $S/clip2
CLIP_S=10 FPS=60 SIDE=960x540 GFX_ARGS="--gfx-preset=high" MESA_SHADER_CACHE_DIR=$S/mesa nice -n 19 tools/ab_clip.sh \
	"$S/clip2/fahrt_paris_50kmh.mp4" --stage=luettich_paris --from=luettich --start-km=387.6 --hour=12 \
	--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-target=50 --autopilot-refuel=never \
	--no-countdown --start-speed=50 > "$S/logs/clip2.log" 2>&1
echo "clip2 exit $? $(date +%H:%M)"
echo "=== chain_clip2 fertig $(date +%H:%M)"
