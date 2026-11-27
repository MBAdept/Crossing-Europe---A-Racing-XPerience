#!/usr/bin/env bash
# W6: review views of a landmark model beside the road (game camera, race light) next to its Arcade sprite.
#   views_lm.sh <tag> <id> [x=40]
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
cd $WT
TAG=$1; M=$2; X=${3:-40}
mkdir -p $S/shots/$TAG
for h in 12 22; do
	waitmem; t0=$(date +%s)
	nice -n 10 tools/models/prop_scene.sh $S/shots/$TAG/dist_h$h.png --models=$M --mode=dist --dist=80,250,600,1200 --x=$X --sprite --look=race --hour=$h --preset=high --tile=480x480 --vis=2000 > $S/logs/v_${TAG}_dist_$h.log 2>&1
	echo "VIEW $TAG dist h$h exit $? $(( $(date +%s) - t0 )) s"
done
echo "=== views $TAG fertig $(date +%H:%M)"
