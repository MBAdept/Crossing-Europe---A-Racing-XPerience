#!/bin/bash
# QA-R7a queue 3 (after queue2): the border roofs that gained an end pillar with R7a (not in R7a's pictures), R7a and base
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a/sh/common.sh
mkdir -p "$S/done"
step() { [ -f "$S/done/$1" ]; }
mark() { touch "$S/done/$1"; }
echo "$(date -u +%H:%M:%S) start queue3"
FLYR="--hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=80 --shot-times=1,2"
for w in mine base; do
	wt=$WT; out=$D/r7a
	[ "$w" = base ] && { wt=$BASE; out=$D/basis; }
	for spec in "R6:--stage=berlin_posen --from=berlin --start-km=94.2" "R7:--stage=bruessel_calais --from=calais --start-km=54.2"; do
		n=${spec%%:*}; a=${spec#*:}
		step "roof_${w}_$n" && continue
		memwait; t0=$SECONDS
		# shellcheck disable=SC2086
		(cd "$wt" && XDG_DATA_HOME=$S/xdg GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 nice -n 10 tools/ab_shot.sh "$out/${n}_high" $a $FLYR > "$out/${n}_high.run.log" 2>&1)
		echo "$(date -u +%H:%M:%S) $w $n exit=$? $((SECONDS - t0)) s"; mark "roof_${w}_$n"
	done
done
echo "$(date -u +%H:%M:%S) done queue3"
