#!/usr/bin/env bash
# KRITIK-4 batch 2: close-ups (day, night), level swaps (medium, high), shimmer (sub-pixel steps), approach clips.
# Waits for batch 1. One job after the other (nice 19 inside the run scripts). Progress in $K/logs/batch2.log
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4
L=$K/logs/batch2.log
: > "$L"
until grep -q BATCH1_DONE $K/logs/batch1.log 2>/dev/null; do sleep 10; done
R="props/house_med@20;props/church@20;props/factory@25;props/windmill@20"
C="props/building_shop@20;props/building_oldtown@20;props/building_block_a@20;props/building_block_b@20;props/building_tall@30"
B="props/houseboat@20;props/ferry_ship@60*0.4;props/bridge_lamp@6;props/bridge_truss_arch@0"
for hour in 12 23; do
	tag=${hour/./_}
	$K/k4.sh nah_land_$tag --mode=close --look=race --hour=$hour --preset=high --views=front,oblique,road,roof,back "--items=$R" >> "$L" 2>&1
	$K/k4.sh nah_stadt_$tag --mode=close --look=race --hour=$hour --preset=high --views=front,oblique,road,roof,back "--items=$C" >> "$L" 2>&1
	$K/k4.sh nah_rest_$tag --mode=close --look=race --hour=$hour --preset=high --views=front,oblique,road,roof,back "--items=$B" >> "$L" 2>&1
done
# level swaps at the switch distances of the presets (UMSCHALT lines): x as close as the census allows
$K/ps.sh lods_land_mittel --mode=lods --look=race --hour=12 --preset=medium --x=34 --sprite --models=props/house_med,props/church,props/factory >> "$L" 2>&1
$K/ps.sh lods_stadt_mittel --mode=lods --look=race --hour=12 --preset=medium --x=18 --sprite --models=props/building_shop,props/building_oldtown,props/building_block_a,props/building_block_b >> "$L" 2>&1
$K/ps.sh lods_land_hoch --mode=lods --look=race --hour=12 --preset=high --x=34 --sprite --models=props/house_med,props/church,props/factory >> "$L" 2>&1
$K/ps.sh lods_stadt_hoch --mode=lods --look=race --hour=12 --preset=high --x=18 --sprite --models=props/building_shop,props/building_oldtown,props/building_block_a,props/building_block_b >> "$L" 2>&1
$K/ps.sh lods_nacht_mittel --mode=lods --look=race --hour=23 --preset=medium --x=18 --models=props/building_shop,props/building_block_b,props/house_med,props/church >> "$L" 2>&1
$K/ps.sh lods_pylon --mode=lods --look=race --hour=12 --preset=medium --x=7.5 --sprite --models=props/bridge_pylon,props/building_tall >> "$L" 2>&1
# shimmer: sub-pixel sideways steps, model against the sprite stand-in
$K/ks.sh flimmer_bruecke --mode=sparkle --look=race --hour=12 --preset=medium --dists=50,100,250,400 --x=7 --sprite --models=props/bridge_pylon,props/bridge_lamp >> "$L" 2>&1
$K/ks.sh flimmer_portal --mode=sparkle --look=race --hour=12 --preset=medium --dists=50,100,250,400 --x=0 --sprite --models=props/bridge_truss_arch >> "$L" 2>&1
$K/ks.sh flimmer_bauten --mode=sparkle --look=race --hour=12 --preset=medium --dists=60,120,250,400 --x=20 --sprite --models=props/building_block_b,props/building_tall,props/windmill,props/factory >> "$L" 2>&1
# approach clips at 120 km/h, 30 fps (frames -> mp4 later)
mkdir -p $K/clips
$K/k4.sh clips/pylon --mode=approach --look=race --hour=12 --preset=medium --from=320 --to=10 --kmh=120 --fps=30 "--items=props/bridge_pylon@7.5" >> "$L" 2>&1
$K/k4.sh clips/portal --mode=approach --look=race --hour=12 --preset=medium --from=400 --to=4 --kmh=120 --fps=30 "--items=props/bridge_truss_arch@0" >> "$L" 2>&1
$K/k4.sh clips/block --mode=approach --look=race --hour=12 --preset=medium --from=260 --to=20 --kmh=80 --fps=30 "--items=props/building_block_b@22" >> "$L" 2>&1
echo BATCH2_DONE >> "$L"
