#!/usr/bin/env bash
# AS3 scratch: the final pictures and measurements, one heavy job after the other (nice 19)
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
TREES="props/tree_oak,props/tree_birch,props/tree_beech,props/tree_poplar,props/tree_olive,props/tree_pine,props/tree_spruce,props/tree_cypress,props/tree_palm"
VARS="props/tree_oak_b,props/tree_birch_b,props/tree_beech_b,props/tree_poplar_b,props/tree_olive_b,props/tree_pine_b,props/tree_spruce_b,props/tree_cypress_b,props/tree_palm_b"
LOW="props/bush_round,props/bush_round_b,props/bush_low,props/cover_bush,props/cover_grass,props/heather,props/rock_a,props/rock_b,props/cliff"
step() { echo "=== $1 $(date +%H:%M:%S)"; }
for h in 12 19.5 23; do
	step "stufen baeume $h"
	$S/scene.sh $S/shots/f_lods_baeume_$h.png --mode=lods --look=race --hour=$h --sprite --models=$TREES > $S/logs/f_stufen_baeume_$h.txt 2>&1
	step "stufen varianten $h"
	$S/scene.sh $S/shots/f_lods_varianten_$h.png --mode=lods --look=race --hour=$h --sprite --models=$VARS > $S/logs/f_stufen_varianten_$h.txt 2>&1
	step "stufen niedrig $h"
	$S/scene.sh $S/shots/f_lods_niedrig_$h.png --mode=lods --look=race --hour=$h --sprite --models=$LOW > $S/logs/f_stufen_niedrig_$h.txt 2>&1
done
step "deckung 20 m"
$S/scene.sh $S/shots/f_lods_d20.png --mode=lods --look=race --hour=12 --d0=20 --d1=200 --models=$TREES,$VARS,props/bush_round,props/bush_round_b,props/bush_low,props/cover_bush,props/heather > $S/logs/f_d20.txt 2>&1
step "overdraw 20 m"
nice -n 19 godot --headless --path . -s "$S/overdraw.gd" -- --dist=20 --models=$TREES,$VARS,props/bush_round,props/bush_round_b,props/bush_low,props/cover_bush,props/heather > $S/logs/f_overdraw20.txt 2>&1
step "clip"
rm -rf $S/clip2
mkdir -p $S/clip2
$S/scene.sh $S/clip2/c.png --mode=clip --look=race --hour=12 --models=props/tree_oak,props/tree_birch,props/tree_beech,props/tree_poplar,props/tree_spruce,props/tree_pine > $S/logs/f_clip.txt 2>&1
for g in "props/tree_*" "props/bush_*" "props/cover_*" "props/heather" "props/rock_*" "props/cliff"; do
	n=$(echo "$g" | tr -d '/*' | sed 's/props//')
	step "kontakt $g"
	nice -n 19 tools/models_contact_sheet.sh $S/shots/f_kontakt_${n}_tag.png --only="$g" --cols=6 --tile=300x240 > $S/logs/f_kontakt_${n}_tag.txt 2>&1
	nice -n 19 tools/models_contact_sheet.sh $S/shots/f_kontakt_${n}_nacht.png --only="$g" --cols=6 --tile=300x240 --night > $S/logs/f_kontakt_${n}_nacht.txt 2>&1
done
step "fertig"
