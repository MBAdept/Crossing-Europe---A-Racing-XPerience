#!/usr/bin/env bash
# AS5a2: review pictures.  v2.sh <tag> <items> <what...>   items: "model@x*scale;..."  what: close dist lods
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
TAG=$1; shift
ITEMS=$1; shift
for w in "$@"; do
case $w in
close)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/close_h$h --mode=close "--items=$ITEMS" --views=road,oblique,front --look=race --hour=$h --preset=high
	done ;;
closed)
	$S/k5.sh k5_scene $TAG/close_h12 --mode=close "--items=$ITEMS" --views=road,oblique,front --look=race --hour=12 --preset=high ;;
dist)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/dist_h$h --mode=dist2 "--items=$ITEMS" --dist=10,30,100,250 --sprite --look=race --hour=$h --preset=high --tile=480x400
	done ;;
distd)
	$S/k5.sh k5_scene $TAG/dist_h12 --mode=dist2 "--items=$ITEMS" --dist=10,30,100,250 --sprite --look=race --hour=12 --preset=high --tile=480x400 ;;
lods)
	for h in 12 22; do
		$S/k5.sh k5_scene $TAG/lods_h$h --mode=lods "--models=${ITEMS}" --sprite --x=20 --look=race --hour=$h --preset=medium
	done ;;
esac
done
echo "=== v2 $TAG fertig $(date +%H:%M)"
