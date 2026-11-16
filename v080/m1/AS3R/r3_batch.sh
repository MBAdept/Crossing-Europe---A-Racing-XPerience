#!/usr/bin/env bash
# AS3R round 3: measurements after tuning (one heavy job at a time, nice 19)
#   r3_batch.sh <tag>
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
TAG=${1:-r3}
TREES="props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b,props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b,props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b,props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b,props/tree_palm,props/tree_palm_b"
for h in 12 19.5 23; do
	echo "=== levels $h $(date +%H:%M:%S)"
	$S/kritik.sh ${TAG}_levels_h$h --mode=levels --look=race --preset=medium --hour=$h --models=$TREES,props/bush_round,props/bush_low,props/heather > /dev/null 2>&1
	grep -E "^SPRUNG" $S/logs/${TAG}_levels_h$h.log | sed -E 's/Sättigung/S/g; s/Helligkeit/H/g; s/Kontrast/K/g; s/Farbton/F/g'
done
echo "=== lods $(date +%H:%M:%S)"
$S/scene.sh $S/shots/${TAG}_lods_h12.png --mode=lods --look=race --preset=medium --hour=12 --sprite --models=$TREES,props/bush_round,props/bush_low,props/heather > $S/logs/${TAG}_lods_h12.txt 2>&1
grep -E "^UMSCHALT" $S/logs/${TAG}_lods_h12.txt | sed -E 's/Fernbild>Sprite.*//; s/der 3x3-Blöcke geändert/Bl/; s/der Pixel/px/' | cut -c1-240
echo "=== fertig $(date +%H:%M:%S)"
