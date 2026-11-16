#!/usr/bin/env bash
# KRITIK-3: extra review modes, one after the other (nice 19 inside kritik.sh)
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-3
# wait for the distance batch
until grep -q BATCH_DONE $K/logs/batch_dist.log; do sleep 10; done
R="--look=race --preset=medium"
$K/kritik.sh turn_trees --mode=turn $R --dist=25 --x=9 --models=props/tree_oak,props/tree_birch,props/tree_beech,props/tree_spruce,props/tree_pine,props/tree_palm,props/bush_round,props/rock_a
$K/kritik.sh turn_cliff --mode=turn $R --dist=70 --x=22 --tile=480x300 --models=props/cliff
$K/kritik.sh slope_30 --mode=slope $R --slope=30 --dist=14 --x=8 --models=props/tree_oak,props/tree_birch,props/tree_spruce,props/tree_palm,props/tree_olive,props/bush_round,props/bush_low,props/heather,props/rock_a,props/rock_b
$K/kritik.sh slope_cliff --mode=slope $R --slope=25 --dist=60 --x=22 --models=props/cliff
$K/kritik.sh under_city --mode=under $R --sprite --dist=10 --x=3.5 --scale=0.55 --models=props/tree_beech,props/tree_beech_b
$K/kritik.sh under_city6 --mode=under $R --sprite --dist=6 --x=3.5 --scale=0.6 --models=props/tree_beech,props/tree_palm
$K/kritik.sh under_road --mode=under $R --sprite --dist=12 --x=7 --models=props/tree_oak,props/tree_birch,props/tree_spruce,props/tree_pine,props/bush_round,props/heather
$K/kritik.sh sparkle --mode=sparkle $R --sprite --dists=40,80,150 --steps=8 --sub=0.25 --thr=0.2 --models=props/tree_oak,props/tree_birch,props/tree_poplar,props/tree_spruce,props/tree_pine,props/tree_palm
for h in 12 19.5 23; do
	$K/kritik.sh levels_h$h --mode=levels --look=race --preset=medium --hour=$h --models=props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b,props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b,props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b,props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b,props/tree_palm,props/tree_palm_b,props/bush_round,props/bush_low,props/heather
done
echo EXTRA_DONE
