#!/usr/bin/env bash
# AS3R round 6: check the wood cut (oak_b twigs), the pine's calmer rims and palm_b
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
R="--look=race --preset=medium"
echo "=== near $(date +%H:%M:%S)"
$S/scene.sh $S/shots/r6_near15.png --mode=dist $R --hour=12 --sprite --dist=15 --zoom=2 --models=props/tree_oak_b,props/tree_beech,props/tree_oak > /dev/null 2>&1
echo "=== sparkle $(date +%H:%M:%S)"
$S/kritik.sh r6_sparkle --mode=sparkle $R --sprite --dists=40,80,150 --steps=8 --sub=0.25 --thr=0.2 --models=props/tree_pine,props/tree_oak > /dev/null 2>&1
grep -E "^FLIMMER" $S/logs/r6_sparkle.log
echo "=== outline $(date +%H:%M:%S)"
$S/kritik.sh r6_outline --mode=outline $R --models=props/tree_palm_b,props/tree_pine,props/tree_oak_b > /dev/null 2>&1
grep -E "^UMRISS" $S/logs/r6_outline.log | cut -c1-200
echo "=== levels $(date +%H:%M:%S)"
$S/kritik.sh r6_levels_h12 --mode=levels $R --hour=12 --models=props/tree_pine,props/tree_pine_b,props/tree_palm_b,props/tree_oak_b,props/tree_birch > /dev/null 2>&1
grep -E "^SPRUNG" $S/logs/r6_levels_h12.log | sed -E 's/Sättigung/S/g; s/Helligkeit/H/g; s/Kontrast/K/g; s/Farbton/F/g'
echo "=== fertig $(date +%H:%M:%S)"
