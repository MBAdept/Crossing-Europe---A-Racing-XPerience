#!/usr/bin/env bash
# KRITIK-5a2 chain3: drive clips (test street, 50 km/h, medium) + race clip Amsterdam 50 km/h
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
source $K/items.sh
while pgrep -f "KRITIK-5a2/chain1.sh" > /dev/null; do sleep 30; done
drive() {
  st=$1; as=$2
  d=$K/clips/${st}_${as}
  [ -f $d/f_149.png ] && return
  mkdir -p $d
  $K/k5.sh k5_scene ../clips/${st}_${as}/f --mode=drive "--items=${!st}" --as=$as --kmh=50 --secs=2.5 --from=0 --look=race --hour=12 --preset=medium | grep -v '^SWAP' | head -3
}
drive SPAR model
drive SPAR sprite
# race clip Amsterdam, 50 km/h held, medium
mkdir -p $K/clip
if [ ! -f $K/clip/fahrt_amsterdam_50kmh.mp4 ]; then
  source $K/env.sh; waitmem; cd $K/tree; st=$(date +%s)
  CLIP_S=6 FPS=60 SIDE=1280x720 CRF=16 KEEP_AVI=0 GFX_ARGS="--gfx-preset=medium" MESA_SHADER_CACHE_DIR=$K/mesa CLIP_TIMEOUT=3600 nice -n 19 tools/ab_clip.sh \
    "$K/clip/fahrt_amsterdam_50kmh.mp4" --stage=bremen_amsterdam --from=bremen --start-km=357.2 --hour=12 \
    --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-target=50 --autopilot-refuel=never \
    --no-countdown --start-speed=50 > $K/logs/clip_am.log 2>&1
  echo "clip_am exit $? $(( $(date +%s) - st )) s"
fi
drive SAMS model
drive SBER model
echo "=== chain3 fertig $(date +%H:%M)"
