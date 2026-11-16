#!/usr/bin/env bash
# KRITIK-3: distance sheets (15/40/100/250 m) with the Arcade sprite, race light, medium, at three hours
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-3
G1=props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b
G2=props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b
G3=props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b
G4=props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b
G5=props/tree_palm,props/tree_palm_b,props/bush_round,props/bush_round_b
G6=props/bush_low,props/heather,props/rock_a,props/rock_b,props/cliff
for hour in 12 19.5 23; do
	for g in 1 2 3 4 5 6; do
		v=G$g
		$K/run_dist.sh dist_g${g}_h${hour} $hour medium "${!v}" --dist=15,40,100,250
	done
done
echo BATCH_DONE
