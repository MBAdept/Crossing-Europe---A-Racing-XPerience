#!/usr/bin/env bash
# AS5aR2: lod1 leaf cards for Südhaus and Loire house (re-export + their views again), the far-facade test without
# fog, then A/B at the city arrivals (high + medium, noon / dusk / 22:00) and the 50 km/h clip through Paris
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
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
$S/k5.sh k6_scene fin/lodcol_h12_nofog --mode=lodcol "--models=props/city_french_sud,props/city_paris_haussmann,props/city_swiss_laube,props/city_belgian_stone" --dists=60,120,250 --x=20 --sprite --look=race --hour=12 --preset=high --vis=100000 --tile=320x260 | grep -E "LODCOL" > $S/logs/fin/lodcol_h12_nofog.log
echo "STAGE ab $(date +%H:%M)"
$S/ab_all.sh $S/ab "${RUNS:-pa:high:22 pa:high:12 be:high:22 am:high:12 ly_out:high:12 hh:high:22 br:medium:19.5 pa:medium:19.5}"
if [ -z "${NOCLIP:-}" ]; then
	waitmem
	mkdir -p $S/clip
	CLIP_S=10 FPS=60 SIDE=960x540 GFX_ARGS="--gfx-preset=high" nice -n 19 tools/ab_clip.sh \
		"$S/clip/fahrt_paris_50kmh.mp4" --stage=luettich_paris --from=luettich --start-km=387.6 --hour=12 \
		--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-target=50 --autopilot-refuel=never \
		--no-countdown --start-speed=50 > "$S/logs/clip.log" 2>&1
	echo "clip exit $? $(date +%H:%M)"
fi
echo "=== chain_ab fertig $(date +%H:%M)"
