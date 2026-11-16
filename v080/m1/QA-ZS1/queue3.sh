#!/usr/bin/env bash
# QA-ZS1 queue 3 (after the A/B queue was stopped by the 30-min limit during fly_new): flying start in the OLD build,
# comparison with the NEW build, then queue2 (probe, render check + breaks, golden check, Wine).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
OLD=$S/old_lin/CrossingEurope-ZS1.x86_64
NEW=$S/lin/CrossingEurope-ZS1.x86_64
O=$S/ab
COMMON=(--seed=11 --autopilot --autopilot-refuel=never --gfx-preset=medium)
FLY=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --traffic-warmup --no-countdown --start-speed=120 --start-km=2 "${COMMON[@]}" --shot-times=1,3)
echo "== fly_old $(date -u +%T)"
identify "$O/fly_new_modern_00.png" "$O/fly_new_modern_01.png"
bash $S/ab_export.sh "$OLD" "$O/fly_old" "modern" "${FLY[@]}"
cmpfly() {
	for nn in 00 01; do
		echo "fly $nn: $1 $(md5sum < "$O/${1}_modern_$nn.png" | cut -c1-12) $2 $(md5sum < "$O/${2}_modern_$nn.png" | cut -c1-12) AE=$(compare -metric AE "$O/${1}_modern_$nn.png" "$O/${2}_modern_$nn.png" null: 2>&1)"
	done
}
cmpfly fly_new fly_old
if ! cmp -s "$O/fly_new_modern_00.png" "$O/fly_old_modern_00.png" || ! cmp -s "$O/fly_new_modern_01.png" "$O/fly_old_modern_01.png"; then
	echo "== not identical: second run of the NEW build (noise?) $(date -u +%T)"
	bash $S/ab_export.sh "$NEW" "$O/fly_new2" "modern" "${FLY[@]}"
	cmpfly fly_new fly_new2
	cmpfly fly_new2 fly_old
fi
echo "== queue2 $(date -u +%T)"
bash $S/queue2.sh > $S/queue2.log 2>&1
tail -70 $S/queue2.log
echo Q3DONE
