#!/usr/bin/env bash
# AS4R scratch: measurements of the reviewer (flicker, level swaps, factory turned at night).  batch_measure.sh <tag>
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
T=${1:-m1}
L=$S/logs/batch_$T.log
: > "$L"
$S/k4.sh ${T}_flimmer_bauten --mode=sparkle --look=race --hour=12 --preset=medium --dists=60,120,250,400 --x=20 --sprite --models=props/building_block_b,props/building_tall,props/windmill,props/factory >> "$L" 2>&1
$S/k4.sh ${T}_flimmer_bruecke --mode=sparkle --look=race --hour=12 --preset=medium --dists=50,100,250,400 --x=7 --sprite --models=props/bridge_pylon,props/bridge_lamp >> "$L" 2>&1
$S/k4.sh ${T}_flimmer_portal --mode=sparkle --look=race --hour=12 --preset=medium --dists=50,100,250,400 --x=0 --sprite --models=props/bridge_truss_arch >> "$L" 2>&1
$S/k4.sh ${T}_lods_land_mittel --mode=lods --look=race --hour=12 --preset=medium --x=34 --sprite --models=props/house_med,props/church,props/factory >> "$L" 2>&1
$S/k4.sh ${T}_lods_stadt_mittel --mode=lods --look=race --hour=12 --preset=medium --x=18 --sprite --models=props/building_shop,props/building_oldtown,props/building_block_a,props/building_block_b >> "$L" 2>&1
$S/k4.sh ${T}_lods_nacht_mittel --mode=lods --look=race --hour=23 --preset=medium --x=18 --models=props/building_shop,props/building_block_b,props/house_med,props/church >> "$L" 2>&1
$S/k4.sh ${T}_fabrik_dreh_nacht --mode=turn --look=race --hour=23 --preset=high --dist=70 --x=0 --yaws=0,30,60,90,180,270,315,330 --lod=lod0 --models=props/factory >> "$L" 2>&1
echo BATCH_DONE >> "$L"
