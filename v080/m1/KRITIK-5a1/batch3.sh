#!/usr/bin/env bash
# KRITIK-5a1 batch 3: drive clips at 50 km/h (model medium, sprite), one model high
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
source $K/items.sh
mkdir -p $K/clips
$K/k5.sh k5_scene outline_all --mode=outline2 "--items=${ALL//,/;}" --look=race --hour=12 --preset=high | grep UMRISS
$K/k5.sh tint_scene tint_all --mode=tint "--items=props/city_german_house@26#e8b8a4;props/city_german_mietshaus@23#e0b09c;props/city_german_mietshaus@23#f6eee2;props/city_german_gruenderzeit@22#f6eedc;props/city_german_gruenderzeit@22#ece4d0" --dist=40 --look=race --hour=12 --preset=high --tile=480x400 | tail -2
for spec in SOLD:model:medium SOLD:sprite:medium SHAN:model:medium SGER:model:medium SHAN:sprite:medium SGER:sprite:medium SOLD:model:high; do
	IFS=: read -r st as pr <<< "$spec"
	d=$K/clips/${st}_${as}_${pr}
	rm -rf $d; mkdir -p $d
	$K/k5.sh k5_scene ../clips/${st}_${as}_${pr}/f --mode=drive "--items=${!st}" --as=$as --kmh=50 --secs=4 --look=race --hour=12 --preset=$pr | grep -v "^SWAP" | head -5
done
$K/k5.sh k5_scene spark6 --mode=sparkcam "--models=props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_hanse_gabled,props/city_german_gruenderzeit,props/city_german_old_barock,props/city_german_mietshaus" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium | grep FLIMMER
echo "=== batch3 fertig $(date +%H:%M)"
