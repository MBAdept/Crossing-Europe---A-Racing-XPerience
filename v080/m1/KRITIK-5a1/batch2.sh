#!/usr/bin/env bash
# KRITIK-5a1 batch 2: drive clips at 50 km/h (model medium + high, sprite), shimmer (sparkcam), tint
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
source $K/items.sh
mkdir -p $K/clips
for st in SOLD SGER SHAN; do
	for as in model sprite; do
		mkdir -p $K/clips/${st}_${as}_medium
		$K/k5.sh k5_scene ../clips/${st}_${as}_medium/f --mode=drive "--items=${!st}" --as=$as --kmh=50 --secs=4 --look=race --hour=12 --preset=medium
		grep "^SWAP" $K/logs/../clips/${st}_${as}_medium/f.log 2>/dev/null | head -0
	done
done
$K/k5.sh k5_scene spark_med_h12 --mode=sparkcam "--models=$ALL" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium
echo "=== batch2 fertig $(date +%H:%M)"
