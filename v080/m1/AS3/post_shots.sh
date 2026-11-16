#!/usr/bin/env bash
# AS3 scratch: after final_shots.sh – the fog picture and the A/B runs on the final head (one job at a time)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3
echo "=== nebel $(date +%H:%M:%S)"
$S/scene.sh $S/shots/f_nebel.png --mode=dist --dist=300,500,700,850 --look=race --hour=12 --sprite --tile=200x160 \
	--models=props/tree_oak,props/tree_beech,props/tree_spruce,props/tree_poplar,props/tree_cypress,props/tree_palm > $S/logs/f_nebel.txt 2>&1
tail -2 $S/logs/f_nebel.txt
$S/ab_final.sh
