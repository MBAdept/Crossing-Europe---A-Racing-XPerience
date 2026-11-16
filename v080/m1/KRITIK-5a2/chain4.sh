#!/usr/bin/env bash
# KRITIK-5a2 chain4: wait for the running drive clip, then the race clip Amsterdam 50 km/h (medium, 6 s)
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
while pgrep -f "tools/kritik/k5_scene.gd" > /dev/null; do sleep 20; done
echo "drive SPAR model fertig $(date +%H:%M)"
mkdir -p $K/clip
source $K/env.sh; waitmem; cd $K/tree; st=$(date +%s)
CLIP_S=6 FPS=60 SIDE=1280x720 CRF=16 GFX_ARGS="--gfx-preset=medium" MESA_SHADER_CACHE_DIR=$K/mesa CLIP_TIMEOUT=3600 nice -n 19 tools/ab_clip.sh \
  "$K/clip/fahrt_amsterdam_50kmh.mp4" --stage=bremen_amsterdam --from=bremen --start-km=357.2 --hour=12 \
  --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-target=50 --autopilot-refuel=never \
  --no-countdown --start-speed=50 > $K/logs/clip_am.log 2>&1
echo "clip_am exit $? $(( $(date +%s) - st )) s $(date +%H:%M)"
echo "=== chain4 fertig $(date +%H:%M)"
