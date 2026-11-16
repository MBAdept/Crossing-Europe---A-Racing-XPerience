#!/usr/bin/env bash
# AS4R scratch: the reviewer's views of the reworked models (race look), one render after the other.
#   batch_views.sh <tag>      -> $S/shots/<tag>_*.png, log $S/logs/batch_<tag>.log
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
T=${1:-v1}
L=$S/logs/batch_$T.log
: > "$L"
G1="props/house_med@34;props/church@40;props/factory@49;props/windmill@90"
G2="props/building_shop@17.6;props/building_oldtown@15.5;props/building_block_a@21.5;props/building_block_b@22"
G3="props/building_tall@67.6*2.15;props/church@69*2.2"
G4="props/bridge_pylon@7.5;props/bridge_lamp@6;props/bridge_truss_arch@0"
G5="props/houseboat@25;props/ferry_ship@100*0.4"
for hour in 12 23; do
	tag=${hour/./_}
	$S/k4.sh ${T}_d_land_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=50,100,250,400 "--items=$G1" >> "$L" 2>&1
	$S/k4.sh ${T}_d_stadt_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=30,100,250,400 "--items=$G2" >> "$L" 2>&1
	$S/k4.sh ${T}_d_gross_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=100,250,400,600 "--items=$G3" >> "$L" 2>&1
	$S/k4.sh ${T}_d_bruecke_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=30,100,250,400 "--items=$G4" >> "$L" 2>&1
done
$S/k4.sh ${T}_d_schiffe_12 --mode=dist2 --look=race --hour=12 --preset=medium --sprite --water --dist=60,100,250,400 "--items=$G5" >> "$L" 2>&1
$S/k4.sh ${T}_d_land_19_5 --mode=dist2 --look=race --hour=19.5 --preset=medium --sprite --dist=50,100,250,400 "--items=$G1" >> "$L" 2>&1
R="props/house_med@20;props/church@20;props/factory@25;props/windmill@20"
C="props/building_shop@20;props/building_oldtown@20;props/building_block_a@20;props/building_block_b@20;props/building_tall@30"
for hour in 12 23; do
	$S/k4.sh ${T}_nah_land_$hour --mode=close --look=race --hour=$hour --preset=high --views=front,oblique,road,back "--items=$R" >> "$L" 2>&1
	$S/k4.sh ${T}_nah_stadt_$hour --mode=close --look=race --hour=$hour --preset=high --views=front,oblique,road,back "--items=$C" >> "$L" 2>&1
done
echo BATCH_DONE >> "$L"
