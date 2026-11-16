#!/usr/bin/env bash
# AS5aR1: review pictures of a round.  views.sh <tag> [what...]   what: close drive lods spark erker rail dist
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
TAG=$1; shift
WHAT="${*:-close erker}"
K2="props/city_german_old_fachwerk@23.5;props/city_german_old_fachwerk_b@18.2;props/city_german_old_barock@23.6*1.05;props/city_hanse_gabled@25.3"
SOLD="props/city_german_old_fachwerk@23.5;props/city_german_old_fachwerk_b@-18.2;props/city_german_old_barock@24.6*1.05;props/city_german_old_fachwerk@-23.5;props/city_german_old_fachwerk_b@18.2;props/city_german_old_barock@-24.6*1.05"
SHAN="props/city_hanse_gabled@25.3;props/city_hanse_gabled@-25.3*1.05;props/city_hanse_speicher@28.3;props/city_hanse_gabled@-24.3;props/city_hanse_gabled@26.0*1.1;props/city_hanse_speicher@-27.0*0.95"
for w in $WHAT; do
case $w in
close)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/close_h$h --mode=close "--items=$K2" --views=road,oblique,front --look=race --hour=$h --preset=high
	done ;;
erker)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/erker_h$h --mode=close "--items=props/city_german_old_fachwerk_b@18.2" \
			"--views=-12,6,7:-7.75,7.5,0.8|-6,3,9:-7.75,5,0.5|-14,2,-2:-7,6,5" --look=race --hour=$h --preset=high
	done ;;
drive)
	for st in SOLD SHAN; do
		for h in 12 22; do
			mkdir -p $S/shots/$TAG/drive_${st}_h$h
			$S/k5.sh k5_scene $TAG/drive_${st}_h$h/f --mode=drive "--items=${!st}" --as=model --kmh=50 --secs=1.2 --from=0 --look=race --hour=$h --preset=high | grep -v '^SWAP' | head -3
		done
	done ;;
lods)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/lods_h$h --mode=lods "--models=${LODS:-props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_german_old_barock,props/city_hanse_gabled}" --sprite --x=20 --look=race --hour=$h --preset=medium
	done ;;
spark)
	$S/k5.sh k5_scene $TAG/spark --mode=sparkcam "--models=${SPARK:-props/city_german_old_fachwerk,props/city_german_old_fachwerk_b}" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium ;;
rail)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/rail_h$h --mode=dist2 "--items=props/city_german_mietshaus@22.6;props/city_german_gruenderzeit@22.3*1.06" --dist=15,40,80,110 --sprite --look=race --hour=$h --preset=high --tile=480x400
	done ;;
dist)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/dist_h$h --mode=dist2 "--items=${DIST:-$K2}" --dist=10,30,100,250 --sprite --look=race --hour=$h --preset=high --tile=480x400
	done ;;
esac
done
echo "=== views $TAG fertig $(date +%H:%M)"
