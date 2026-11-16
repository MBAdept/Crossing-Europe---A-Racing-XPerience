#!/usr/bin/env bash
# AS3R round 4: check the tuned models (noon levels + dist of the bushes)
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
TAG=${1:-r4}
M="props/tree_pine,props/tree_pine_b,props/tree_spruce,props/tree_spruce_b,props/tree_palm,props/tree_palm_b,props/bush_round,props/bush_round_b,props/bush_low"
echo "=== levels 12 $(date +%H:%M:%S)"
$S/kritik.sh ${TAG}_levels_h12 --mode=levels --look=race --preset=medium --hour=12 --models=$M > /dev/null 2>&1
grep -E "^SPRUNG" $S/logs/${TAG}_levels_h12.log | sed -E 's/Sättigung/S/g; s/Helligkeit/H/g; s/Kontrast/K/g; s/Farbton/F/g'
echo "=== levels 19.5 $(date +%H:%M:%S)"
$S/kritik.sh ${TAG}_levels_h19 --mode=levels --look=race --preset=medium --hour=19.5 --models=props/tree_spruce,props/tree_spruce_b > /dev/null 2>&1
grep -E "^SPRUNG" $S/logs/${TAG}_levels_h19.log | sed -E 's/Sättigung/S/g; s/Helligkeit/H/g; s/Kontrast/K/g; s/Farbton/F/g'
echo "=== dist bushes $(date +%H:%M:%S)"
$S/scene.sh $S/shots/${TAG}_dist_bush.png --mode=dist --look=race --preset=medium --hour=12 --sprite --dist=15,40 --models=props/bush_round,props/bush_round_b,props/bush_low > /dev/null 2>&1
echo "=== fertig $(date +%H:%M:%S)"
