#!/usr/bin/env bash
# stop batch3 after the old-town model clip, then shorter clips + reduced shimmer set
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
source $K/items.sh
until [ $(ls $K/clips/SOLD_model_medium | wc -l) -ge 241 ]; do sleep 5; done
sleep 3
pkill -f chain3.sh; pkill -f batch3.sh; sleep 1; pkill -f "clips/SOLD_sprite"; pkill -f "clips/SHAN"; sleep 3
echo "batch3 gestoppt $(date +%H:%M)"
for spec in SOLD:sprite:medium SGER:model:medium; do
	IFS=: read -r st as pr <<< "$spec"
	d=$K/clips/${st}_${as}_${pr}
	rm -rf $d; mkdir -p $d
	$K/k5.sh k5_scene ../clips/${st}_${as}_${pr}/f --mode=drive "--items=${!st}" --as=$as --kmh=50 --secs=2.5 --look=race --hour=12 --preset=$pr | grep -v "^SWAP" | head -3
done
$K/k5.sh k5_scene spark3 --mode=sparkcam "--models=props/city_german_old_fachwerk,props/city_german_gruenderzeit,props/city_hanse_gabled" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium | grep FLIMMER
echo "=== chain4 fertig $(date +%H:%M)"
