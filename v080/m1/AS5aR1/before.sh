#!/usr/bin/env bash
# AS5aR1: "before" pictures of the K2/K4 models (close views by day and night, a passing view in a test street)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
TAG=${1:-vor}
K2="props/city_german_old_fachwerk@23.5;props/city_german_old_fachwerk_b@18.2;props/city_german_old_barock@23.6*1.05;props/city_hanse_gabled@25.3"
for h in 12 22; do
	$S/k5.sh k5_scene ${TAG}/close_h$h --mode=close "--items=$K2" --views=road,oblique,front --look=race --hour=$h --preset=high
done
SOLD="props/city_german_old_fachwerk@23.5;props/city_german_old_fachwerk_b@-18.2;props/city_german_old_barock@24.6*1.05;props/city_german_old_fachwerk@-23.5;props/city_german_old_fachwerk_b@18.2;props/city_german_old_barock@-24.6*1.05"
SHAN="props/city_hanse_gabled@25.3;props/city_hanse_gabled@-25.3*1.05;props/city_hanse_speicher@28.3;props/city_hanse_gabled@-24.3;props/city_hanse_gabled@26.0*1.1;props/city_hanse_speicher@-27.0*0.95"
for st in SOLD SHAN; do
	for h in 12 22; do
		mkdir -p $S/shots/${TAG}/drive_${st}_h$h
		$S/k5.sh k5_scene ${TAG}/drive_${st}_h$h/f --mode=drive "--items=${!st}" --as=model --kmh=50 --secs=1.2 --from=0 --look=race --hour=$h --preset=high | grep -v '^SWAP' | head -3
	done
done
echo "=== before $TAG fertig $(date +%H:%M)"
