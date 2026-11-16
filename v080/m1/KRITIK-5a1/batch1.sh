#!/usr/bin/env bash
# KRITIK-5a1 batch 1: distance sheets (3 hours), close-ups (day/night), level swaps, shimmer - one job at a time
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
source $K/items.sh
for st in GER OLD HAN; do
	for h in 12 19.5 22; do
		$K/k5.sh k5_scene dist_${st}_h$h --mode=dist2 "--items=${!st}" --dist=10,30,100,250 --sprite --look=race --hour=$h --preset=high --tile=480x400
	done
done
for st in GER OLD HAN; do
	for h in 12 22; do
		$K/k5.sh k5_scene close_${st}_h$h --mode=close "--items=${!st}" --views=front,oblique,road,back --look=race --hour=$h --preset=high
	done
done
for h in 12 22; do
	$K/k5.sh k5_scene lods_h$h --mode=lods "--models=$ALL" --sprite --x=20 --look=race --hour=$h --preset=medium
done
echo "=== batch1 fertig $(date +%H:%M)"
