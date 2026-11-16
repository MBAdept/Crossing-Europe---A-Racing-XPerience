#!/usr/bin/env bash
# AS3R round 7: fuller lod1 rims - noon levels, swaps and the pine's sparkle
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
R="--look=race --preset=medium"
M="props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b,props/tree_beech,props/tree_beech_b,props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b"
echo "=== levels $(date +%H:%M:%S)"
$S/kritik.sh r7_levels_h12 --mode=levels $R --hour=12 --models=$M > /dev/null 2>&1
grep -E "^SPRUNG" $S/logs/r7_levels_h12.log | sed -E 's/Sättigung/S/g; s/Helligkeit/H/g; s/Kontrast/K/g; s/Farbton/F/g' | cut -c1-200
echo "=== lods $(date +%H:%M:%S)"
$S/scene.sh $S/shots/r7_lods_h12.png --mode=lods $R --hour=12 --sprite --models=$M > $S/logs/r7_lods_h12.txt 2>&1
grep -E "^UMSCHALT" $S/logs/r7_lods_h12.txt | sed -E 's/lod1>Fernbild.*//; s/der 3x3-Blöcke geändert/Bl/; s/der Pixel/px/'
echo "=== sparkle $(date +%H:%M:%S)"
$S/kritik.sh r7_sparkle --mode=sparkle $R --sprite --dists=40,80,150 --steps=8 --sub=0.25 --thr=0.2 --models=props/tree_pine,props/tree_oak,props/tree_birch > /dev/null 2>&1
grep -E "^FLIMMER" $S/logs/r7_sparkle.log | cut -c1-200
echo "=== fertig $(date +%H:%M:%S)"
