#!/usr/bin/env bash
# AS5aR2: lod1 with the lod0 leaf cards (Südhaus, Loire house): re-export, swap/close/dist views again, then the gates
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
[ -d tools/kritik ] || $S/install_tools.sh > /dev/null
echo "STAGE reexport $(date +%H:%M)"
$S/real.sh props/city_french_sud props/city_french_maison
echo "STAGE views $(date +%H:%M)"
source $S/items.sh
G1="props/city_french_sud,props/city_french_maison,props/city_french_immeuble,props/city_belgian_terrace"
for h in 12 22; do
	$S/k5.sh k5_scene fin/lods_G1_h$h --mode=lods "--models=$G1" --sprite --x=20 --look=race --hour=$h --preset=medium | grep -E "UMSCHALT"
	$S/k5.sh k5_scene fin/close_FRA_h$h --mode=close "--items=$FRA" --views=road,oblique,front --look=race --hour=$h --preset=high | grep -c ERROR
done
for h in 12 19.5 22; do
	$S/k5.sh k5_scene fin/dist_FRA_h$h --mode=dist2 "--items=$FRA" --dist=10,30,100,250 --sprite --look=race --hour=$h --preset=high --tile=480x400 | grep -c ERROR
done
$S/k5.sh my_scene fin/spark_fr --mode=sparkcam "--models=props/city_french_maison,props/city_french_sud" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium | grep -E "FLIMMER"
rm -f $S/ab/ly_out_high_h12_ab_01.jpg
$S/ab_all.sh $S/ab "ly_out:high:12"
echo "=== chain_post2 views fertig $(date +%H:%M)"
$S/chain_final.sh det geom keys pck tests golden modern > $S/logs/chain_final.out 2>&1
echo "=== chain_post2 fertig $(date +%H:%M)"
