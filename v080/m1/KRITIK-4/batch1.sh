#!/usr/bin/env bash
# KRITIK-4 batch 1: game camera at distances with the Arcade sprite (race look), day / dusk / night, and the outlines.
# One job after the other (nice 19 inside k4.sh). Progress in $K/logs/batch1.log
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4
L=$K/logs/batch1.log
: > "$L"
G1="props/house_med@34;props/church@40;props/factory@49;props/windmill@90"
G2="props/building_shop@17.6;props/building_oldtown@15.5;props/building_block_a@21.5;props/building_block_b@22"
G3="props/building_tall@67.6*2.15;props/church@69*2.2"
G4="props/bridge_pylon@7.5;props/bridge_lamp@6;props/bridge_truss_arch@0"
G5="props/houseboat@25;props/ferry_ship@100*0.4"
for hour in 12 19.5 23; do
	tag=${hour/./_}
	$K/k4.sh d_land_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=50,100,250,400 "--items=$G1" >> "$L" 2>&1
	$K/k4.sh d_stadt_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=30,100,250,400 "--items=$G2" >> "$L" 2>&1
	$K/k4.sh d_gross_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=100,250,400,600 "--items=$G3" >> "$L" 2>&1
	$K/k4.sh d_bruecke_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --dist=30,100,250,400 "--items=$G4" >> "$L" 2>&1
	$K/k4.sh d_schiffe_$tag --mode=dist2 --look=race --hour=$hour --preset=medium --sprite --water --dist=60,100,250,400 "--items=$G5" >> "$L" 2>&1
done
$K/k4.sh umriss_a --mode=outline2 --ppm=20 --lods=lod0,lod1 "--items=props/house_med;props/church;props/factory;props/windmill;props/building_shop;props/building_oldtown;props/building_block_a;props/building_block_b;props/houseboat;props/bridge_lamp;props/bridge_truss_arch" >> "$L" 2>&1
$K/k4.sh umriss_b --mode=outline2 --ppm=6 --lods=lod0,lod1 "--items=props/building_tall;props/bridge_pylon" >> "$L" 2>&1
$K/k4.sh umriss_c --mode=outline2 --ppm=5 --lods=lod0 "--items=props/ferry_ship" >> "$L" 2>&1
echo BATCH1_DONE >> "$L"
