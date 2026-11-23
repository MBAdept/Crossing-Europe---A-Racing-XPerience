#!/usr/bin/env bash
# FIX-R7b: Modern pictures of the worktree for a list "name:stage:from:km:hour[:preset[:screen]]" (env LIST), prefix PFX
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7b
OUTD=${OUTD:-$S/pics}
C="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
for line in $LIST; do
	IFS=: read -r name stage from km hour preset screen <<<"$line"
	$S/sh/mshot.sh "$OUTD/${PFX}${name}" "${preset:-high}" "${screen:-1280x720}" --stage=$stage --from=$from --start-km=$km --hour=$hour $C | tail -2
done
echo BATCH_DONE
