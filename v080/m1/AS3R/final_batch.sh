#!/usr/bin/env bash
# AS3R: final review renders and measurements on the final models (one heavy job after the other, nice 19)
#   final_batch.sh <tag>
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
cd "$WT"
T=${1:-f}
TREES="props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b,props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b,props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b,props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b,props/tree_palm,props/tree_palm_b"
LOW="props/bush_round,props/bush_round_b,props/bush_low,props/cover_bush,props/cover_grass,props/heather,props/rock_a,props/rock_b,props/cliff"
R="--look=race --preset=medium"
step() { echo "=== $1 $(date +%H:%M:%S)"; }
for h in 12 19.5 23; do
	step "levels $h"
	$S/kritik.sh ${T}_levels_h$h --mode=levels $R --hour=$h --models=$TREES,props/bush_round,props/bush_low,props/heather > /dev/null 2>&1
done
step "lods 12"
$S/scene.sh $S/shots/${T}_lods_h12.png --mode=lods $R --hour=12 --sprite --models=$TREES > $S/logs/${T}_lods_h12.txt 2>&1
$S/scene.sh $S/shots/${T}_lods_low_h12.png --mode=lods $R --hour=12 --sprite --models=$LOW > $S/logs/${T}_lods_low_h12.txt 2>&1
step "outline"
$S/kritik.sh ${T}_outline --mode=outline $R --models=$TREES > /dev/null 2>&1
step "dist noon"
G1="props/tree_oak,props/tree_oak_b,props/tree_birch,props/tree_birch_b"
G2="props/tree_beech,props/tree_beech_b,props/tree_poplar,props/tree_poplar_b"
G3="props/tree_olive,props/tree_olive_b,props/tree_pine,props/tree_pine_b"
G4="props/tree_spruce,props/tree_spruce_b,props/tree_cypress,props/tree_cypress_b"
G5="props/tree_palm,props/tree_palm_b,props/bush_round,props/bush_round_b"
G6="props/bush_low,props/heather,props/rock_a,props/rock_b,props/cliff"
i=0
for g in $G1 $G2 $G3 $G4 $G5 $G6; do
	i=$((i + 1))
	$S/scene.sh $S/shots/${T}_dist_h12_$i.png --mode=dist $R --hour=12 --sprite --dist=15,40,100,250 --models=$g > $S/logs/${T}_dist_h12_$i.txt 2>&1
done
step "dist dusk night"
for h in 19.5 23; do
	$S/scene.sh $S/shots/${T}_dist_h${h}.png --mode=dist $R --hour=$h --sprite --dist=15,40,100,250 --models=props/tree_oak,props/tree_birch,props/tree_spruce,props/tree_palm,props/bush_round > $S/logs/${T}_dist_h$h.txt 2>&1
done
step "slope"
$S/kritik.sh ${T}_slope_30 --mode=slope $R --slope=30 --dist=14 --x=8 --models=props/tree_birch,props/tree_palm,props/bush_round,props/bush_low,props/heather,props/cover_grass,props/rock_a,props/rock_b > /dev/null 2>&1
$S/kritik.sh ${T}_slope_cliff --mode=slope $R --slope=25 --dist=60 --x=22 --models=props/cliff > /dev/null 2>&1
step "turn"
$S/kritik.sh ${T}_turn_cliff --mode=turn $R --dist=70 --x=22 --tile=480x300 --models=props/cliff > /dev/null 2>&1
$S/kritik.sh ${T}_turn_trees --mode=turn $R --dist=25 --x=9 --models=props/tree_oak,props/tree_birch,props/tree_palm,props/bush_round,props/rock_a > /dev/null 2>&1
step "near crowns"
$S/scene.sh $S/shots/${T}_near15.png --mode=dist $R --hour=12 --sprite --dist=15 --zoom=2 --models=props/tree_oak_b,props/tree_beech,props/tree_olive > $S/logs/${T}_near15.txt 2>&1
$S/kritik.sh ${T}_under_city --mode=under $R --sprite --dist=10 --x=3.5 --scale=0.55 --models=props/tree_beech,props/tree_beech_b > /dev/null 2>&1
$S/scene.sh $S/shots/${T}_birch_near.png --mode=dist $R --hour=12 --sprite --dist=8,12,25 --zoom=2 --models=props/tree_birch,props/tree_birch_b > $S/logs/${T}_birch_near.txt 2>&1
step "sparkle"
$S/kritik.sh ${T}_sparkle --mode=sparkle $R --sprite --dists=40,80,150 --steps=8 --sub=0.25 --thr=0.2 --models=props/tree_oak,props/tree_birch,props/tree_poplar,props/tree_spruce,props/tree_pine,props/tree_palm > /dev/null 2>&1
step "fog"
$S/scene.sh $S/shots/${T}_nebel.png --mode=dist --dist=300,500,700,850 $R --hour=12 --sprite --tile=200x160 --models=props/tree_oak,props/tree_birch,props/tree_spruce,props/tree_poplar,props/tree_cypress,props/tree_palm > $S/logs/${T}_nebel.txt 2>&1
step "coverage 20 m + overdraw"
$S/scene.sh $S/shots/${T}_lods_d20.png --mode=lods $R --hour=12 --d0=20 --d1=200 --models=$TREES,props/bush_round,props/bush_round_b,props/bush_low,props/cover_bush,props/heather > $S/logs/${T}_d20.txt 2>&1
nice -n 19 godot --headless --path . -s "$S/overdraw.gd" -- --dist=20 --models=$TREES,props/bush_round,props/bush_round_b,props/bush_low,props/cover_bush,props/heather > $S/logs/${T}_overdraw20.txt 2>&1
step "clip"
rm -rf $S/clip
mkdir -p $S/clip
$S/scene.sh $S/clip/c.png --mode=clip $R --hour=12 --models=props/tree_oak,props/tree_birch,props/tree_beech,props/tree_poplar,props/tree_spruce,props/tree_pine > $S/logs/${T}_clip.txt 2>&1
nice -n 19 ffmpeg -y -loglevel error -framerate 60 -i $S/clip/c_%03d.png -c:v libx264 -pix_fmt yuv420p -crf 20 $S/shots/${T}_clip_120kmh.mp4
step "fertig"
