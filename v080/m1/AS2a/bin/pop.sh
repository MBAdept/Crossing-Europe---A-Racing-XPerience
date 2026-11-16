#!/usr/bin/env bash
# AS2a: game-camera tiles of the traffic cars at a swap distance with both levels (LOD steps).
# usage: pop.sh <dist> <lodA> <lodB> <tag> [models...]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a
D=$1; A=$2; B=$3; TAG=$4
shift 4
PAIRS="${*:-suv:traffic/suv_white van:traffic/van_silver sports:traffic/sports_yellow}"
for pair in $PAIRS; do
	m=${pair%%:*}; s=${pair#*:}
	for L in $A $B; do
		$S/bin/sheet.sh $S/out/raw/pop_${TAG}_${m}_${L}.png --only="traffic/$m" --chase=$D --lods=$L --set=$s --day --tile=480x300 --cols=1 | tail -1
	done
done
