#!/usr/bin/env bash
# AS5aR1: measurements and review pictures on the real exports (one heavy job after the other)
#   meas_final.sh [steps]   steps: validate lods spark outline tint dist close erker drive rail texel
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
source $S/env.sh
cd $WT
STEPS="${*:-validate lods spark outline tint dist close erker drive rail}"
ALL="props/city_german_house,props/city_german_mietshaus,props/city_german_gruenderzeit,props/city_german_office,props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_german_old_barock,props/city_hanse_gabled,props/city_hanse_speicher,props/city_hanse_kontor,props/city_hanse_crane"
GER="props/city_german_house@26.1;props/city_german_mietshaus@22.6;props/city_german_gruenderzeit@22.3*1.06;props/city_german_office@28.6*0.45"
OLD="props/city_german_old_fachwerk@23.5;props/city_german_old_fachwerk_b@18.2;props/city_german_old_barock@23.6*1.05"
HAN="props/city_hanse_gabled@25.3;props/city_hanse_speicher@28.3;props/city_hanse_kontor@42.2*1.11;props/city_hanse_crane@68.8*1.05"
for st in $STEPS; do
	echo "STEP $st $(date +%H:%M)"
	case $st in
	validate)
		python3 tools/blender/validate_models.py --report > $S/logs/validate.log 2>&1
		echo "validate exit $?: $(grep -E 'CHECK|FEHLER' $S/logs/validate.log | head -5 | tr '\n' ' ')" ;;
	lods)
		for h in 12 22; do
			$S/k5.sh k5_scene fin/lods_h$h --mode=lods "--models=$ALL" --sprite --x=20 --look=race --hour=$h --preset=medium | grep UMSCHALT
		done ;;
	spark)
		$S/k5.sh k5_scene fin/spark --mode=sparkcam "--models=props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_hanse_gabled,props/city_german_gruenderzeit" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium | grep -E "FLIMMER|SPARK" ;;
	outline)
		$S/k5.sh k5_scene fin/outline --mode=outline2 "--items=${ALL//,/;}" --look=race --hour=12 --preset=high | grep UMRISS ;;
	tint)
		$S/k5.sh tint_scene fin/tint --mode=tint "--items=props/city_german_house@26#e8b8a4;props/city_german_mietshaus@23#e0b09c;props/city_german_mietshaus@23#f6eee2;props/city_german_gruenderzeit@22#f6eedc;props/city_german_gruenderzeit@22#ece4d0" --dist=40 --look=race --hour=12 --preset=high --tile=480x400 | tail -2 ;;
	dist)
		for g in GER OLD HAN; do
			for h in 12 19.5 22; do
				$S/k5.sh k5_scene fin/dist_${g}_h$h --mode=dist2 "--items=${!g}" --dist=10,30,100,250 --sprite --look=race --hour=$h --preset=high --tile=480x400 | tail -1
			done
		done ;;
	close)
		for g in GER OLD HAN; do
			for h in 12 22; do
				$S/k5.sh k5_scene fin/close_${g}_h$h --mode=close "--items=${!g}" --views=road,oblique,front,back --look=race --hour=$h --preset=high | tail -1
			done
		done ;;
	erker|drive|rail)
		$S/views.sh fin $st ;;
	esac
done
echo "=== meas_final fertig $(date +%H:%M)"
