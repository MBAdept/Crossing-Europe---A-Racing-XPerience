#!/usr/bin/env bash
# AS3R round 1: review renders after the export (one heavy job at a time, nice 19)
#   r1_batch.sh <tag>
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
TAG=${1:-r1}
R="--look=race --preset=medium --hour=12"
TREES="props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b,props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b,props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b,props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b,props/tree_palm,props/tree_palm_b"
echo "=== levels $(date +%H:%M:%S)"
$S/kritik.sh ${TAG}_levels_h12 --mode=levels $R --models=$TREES,props/bush_round,props/bush_low,props/heather > $S/logs/${TAG}_levels_h12.txt 2>&1
grep -E "^SPRUNG" $S/logs/${TAG}_levels_h12.log | head -30
echo "=== lods $(date +%H:%M:%S)"
$S/scene.sh $S/shots/${TAG}_lods_h12.png --mode=lods $R --sprite --models=$TREES > $S/logs/${TAG}_lods_h12.txt 2>&1
grep -E "^UMSCHALT" $S/logs/${TAG}_lods_h12.txt | head -30
echo "=== dist $(date +%H:%M:%S)"
$S/scene.sh $S/shots/${TAG}_dist_a.png --mode=dist $R --sprite --dist=15,40,100,250 --models=props/tree_oak,props/tree_oak_b,props/tree_beech,props/tree_palm,props/tree_palm_b > $S/logs/${TAG}_dist_a.txt 2>&1
$S/scene.sh $S/shots/${TAG}_dist_b.png --mode=dist $R --sprite --dist=15,40,100,250 --models=props/bush_round,props/bush_low,props/heather,props/rock_a,props/cliff > $S/logs/${TAG}_dist_b.txt 2>&1
echo "=== turn cliff $(date +%H:%M:%S)"
$S/kritik.sh ${TAG}_turn_cliff --mode=turn $R --dist=70 --x=22 --tile=480x300 --models=props/cliff > /dev/null 2>&1
echo "=== under $(date +%H:%M:%S)"
$S/kritik.sh ${TAG}_under --mode=under $R --sprite --dist=15 --x=7 --models=props/tree_oak_b,props/tree_beech > /dev/null 2>&1
echo "=== fertig $(date +%H:%M:%S)"
