#!/usr/bin/env bash
# AS1R: game-camera tiles of the traffic cars at a swap distance with both levels (for the LOD-pop measure).
# usage: pop.sh <dist> <lodA> <lodB> <tag>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R
D=$1; A=$2; B=$3; TAG=$4
for pair in "sedan:traffic/sedan_red" "hatch:traffic/hatch_red" "wagon:traffic/wagon_silver"; do
	m=${pair%%:*}; s=${pair#*:}
	for L in $A $B; do
		$S/bin/sheet.sh $S/out/pop_${TAG}_${m}_${L}.png --only="traffic/$m" --chase=$D --lods=$L --set=$s --tile=480x300 --cols=3 | tail -1
	done
done
