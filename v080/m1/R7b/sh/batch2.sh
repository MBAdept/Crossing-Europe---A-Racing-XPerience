#!/usr/bin/env bash
# R7b: after the first batch – Belgrade from km 196.0 (the church is not hidden by a house), then the two clips.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7b
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-2
until grep -q BATCH_DONE $S/batch.log; do sleep 20; done
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
export GFX_ARGS="--gfx-preset=high"
for h in 12 19.5 22; do
	tag=$(echo "$h" | tr -d .)
	echo "== belgrad $h (km 196.0)"
	$S/sh/ab.sh "$D/ab/belgrad_${tag}" --stage=slavonski_brod_belgrad --from=slavonski_brod --start-km=196.0 --hour=$h $COMMON 2>&1 | tail -2
done
for h in 19.5 22; do
	tag=$(echo "$h" | tr -d .)
	echo "== dortmund $h (glow fix)"
	$S/sh/ab.sh "$D/ab/dortmund_${tag}" --stage=bremen_dortmund --from=bremen --start-km=225.0 --hour=$h $COMMON 2>&1 | tail -2
done
export TMPDIR=$S/tmp MESA_SHADER_CACHE_DIR=$S/mesa CLIP_S=20 SIDE=960x540
mkdir -p "$D/clips"
cd $WT
while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
echo "== clip hamburg"
nice -n 10 tools/ab_clip.sh "$D/clips/anfahrt_hamburg.mp4" --stage=kiel_hamburg --from=kiel --start-km=89.0 --hour=12 --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 2>&1 | tail -3
while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
echo "== clip paris"
nice -n 10 tools/ab_clip.sh "$D/clips/anfahrt_paris.mp4" --stage=luettich_paris --from=luettich --start-km=391.5 --hour=12 --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 2>&1 | tail -3
echo BATCH2_DONE
