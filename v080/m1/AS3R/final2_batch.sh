#!/usr/bin/env bash
# AS3R: the review measurements once more on the final head (after the gates; one heavy job after the other, nice 19)
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
cd "$WT"
T=z
echo "HEAD $(git rev-parse --short HEAD)"
TREES="props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b,props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b,props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b,props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b,props/tree_palm,props/tree_palm_b"
R="--look=race --preset=medium"
step() { echo "=== $1 $(date +%H:%M:%S)"; }
for h in 12 19.5 23; do
	step "levels $h"
	$S/kritik.sh ${T}_levels_h$h --mode=levels $R --hour=$h --models=$TREES,props/bush_round,props/bush_low,props/heather > /dev/null 2>&1
done
step "lods 12"
$S/scene.sh $S/shots/${T}_lods_h12.png --mode=lods $R --hour=12 --sprite --models=$TREES > $S/logs/${T}_lods_h12.txt 2>&1
step "outline"
$S/kritik.sh ${T}_outline --mode=outline $R --models=$TREES > /dev/null 2>&1
step "dist noon"
G1="props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b"
G2="props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b"
G3="props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b"
G4="props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b"
G5="props/tree_palm,props/tree_palm_b,props/bush_round,props/bush_round_b"
G6="props/bush_low,props/heather,props/rock_a,props/rock_b,props/cliff"
i=0
for g in $G1 $G2 $G3 $G4 $G5 $G6; do
	i=$((i + 1))
	$S/scene.sh $S/shots/${T}_dist_h12_$i.png --mode=dist $R --hour=12 --sprite --dist=15,40,100,250 --models=$g > $S/logs/${T}_dist_h12_$i.txt 2>&1
done
step "dist dusk night"
for h in 19.5 23; do
	$S/scene.sh $S/shots/${T}_dist_h${h}.png --mode=dist $R --hour=$h --sprite --dist=15,40,100,250 --models=props/tree_oak,props/tree_birch,props/tree_spruce,props/tree_palm,props/bush_round > $S/logs/${T}_dist_h$h.txt 2>&1
done
step "sparkle"
$S/kritik.sh ${T}_sparkle --mode=sparkle $R --sprite --dists=40,80,150 --steps=8 --sub=0.25 --thr=0.2 --models=props/tree_oak,props/tree_birch,props/tree_poplar,props/tree_spruce,props/tree_pine,props/tree_palm > /dev/null 2>&1
step "fertig"
