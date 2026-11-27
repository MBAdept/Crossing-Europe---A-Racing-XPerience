#!/usr/bin/env bash
# W6: review views of models in the game camera with race light, beside the Arcade sprite.
#   views.sh <tag> <id,id,...> [x=9] [what=dist,lods]
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
cd $WT
TAG=$1; M=$2; X=${3:-9}; WHAT=${4:-dist,lods}
mkdir -p $S/shots/$TAG
for w in ${WHAT//,/ }; do
	for h in 12 19.5 22; do
		[ "$w" = lods ] && [ "$h" = 19.5 ] && continue
		waitmem
		t0=$(date +%s)
		case $w in
		dist) nice -n 10 tools/models/prop_scene.sh $S/shots/$TAG/dist_h$h.png --models=$M --mode=dist --dist=10,30,100,250 --x=$X --sprite --look=race --hour=$h --preset=high --tile=480x400 > $S/logs/v_${TAG}_dist_$h.log 2>&1 ;;
		lods) nice -n 10 tools/models/prop_scene.sh $S/shots/$TAG/lods_h$h.png --models=$M --mode=lods --x=$X --sprite --look=race --hour=$h --preset=medium > $S/logs/v_${TAG}_lods_$h.log 2>&1 ;;
		esac
		echo "VIEW $TAG $w h$h exit $? $(( $(date +%s) - t0 )) s"
		grep -E "UMSCHALT|ERROR|SCRIPT" $S/logs/v_${TAG}_${w}_$h.log | head -6
	done
done
echo "=== views $TAG fertig $(date +%H:%M)"
