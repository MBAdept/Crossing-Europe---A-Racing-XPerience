#!/bin/bash
# W6: race A/B pictures (Arcade | Modern, same simulation state) from a list "tag stage from start_km hour" (resumable)
#   ab.sh <list> <logname>
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
export AB_TIMEOUT=${AB_TIMEOUT:-1200}
LIST=$1; LOG=$S/logs/$2.log
cd $WT
while read -r -u 3 tag stage from km hour; do
	[ -z "$tag" ] && continue
	[ -f $S/ab/${tag}_ab_00.jpg ] && continue
	waitmem; t0=$(date +%s)
	nice -n 10 tools/ab_shot.sh $S/ab/$tag --stage=$stage --from=$from --start-km=$km --hour=$hour --weather=normal \
		--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown \
		--start-speed=50 --gfx-preset=high --shot-times=2,5 > $S/ab/$tag.run.log 2>&1 < /dev/null
	echo "$(date +%T) AB $tag exit $? $(( $(date +%s) - t0 )) s" >> $LOG
done 3< $LIST
echo "AB DONE $(date +%T)" >> $LOG
