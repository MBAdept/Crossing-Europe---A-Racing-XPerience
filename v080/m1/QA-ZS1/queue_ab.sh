#!/usr/bin/env bash
# QA-ZS1: all A/B runs of the exported Linux build, one after the other (one Godot run at a time).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
NEW=$S/lin/CrossingEurope-ZS1.x86_64
OLD=$S/old_lin/CrossingEurope-ZS1.x86_64
AB=$S/ab_export.sh
O=$S/ab
mkdir -p "$O"
COMMON=(--seed=11 --autopilot --autopilot-refuel=never --gfx-preset=medium)
echo "== start $(date -u +%T)"
# 1 Kiel - Hamburg, standing start at km 0 (countdown 3 s): 1 / 2.9 s countdown, LOS +0.2 … +4 s
bash $AB "$NEW" "$O/kh" "arcade modern" --stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine "${COMMON[@]}" \
	--shot-times=1,2.9,3.2,3.4,3.7,4,4.5,5,5.5,6,7
echo "== $(date -u +%T)"
# 2 slope: Passau - Regensburg from Passau (+15.8 m on the first 300 m)
bash $AB "$NEW" "$O/passau" "arcade modern" --stage=passau_regensburg --from=passau --hour=12 --weather=normal --vehicle=limousine "${COMMON[@]}" \
	--shot-times=1,4.5,7
echo "== $(date -u +%T)"
# 3 city start: Paris - Tours from Paris, compact car, 15:00
bash $AB "$NEW" "$O/paris" "arcade modern" --stage=paris_tours --from=paris --hour=15 --weather=normal --vehicle=kompakt "${COMMON[@]}" \
	--shot-times=1,4.5,7
echo "== $(date -u +%T)"
# 4 rain: Hamburg - Hannover from Hamburg, 16:00
bash $AB "$NEW" "$O/regen" "arcade modern" --stage=hamburg_hannover --from=hamburg --hour=16 --weather=rain --vehicle=limousine "${COMMON[@]}" \
	--shot-times=1,4.5,7
echo "== $(date -u +%T)"
# 5 night + snow: Warschau - Bialystok from Warschau, 22:00
bash $AB "$NEW" "$O/nacht" "arcade modern" --stage=warschau_bialystok --from=warschau --hour=22 --weather=snow --vehicle=limousine "${COMMON[@]}" \
	--shot-times=1,4.5,7
echo "== $(date -u +%T)"
# 6 flying start at km 2 (S1 of ab_shot.sh) in the NEW and the OLD build, Modern: nothing may have changed
FLY=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --traffic-warmup --no-countdown --start-speed=120 --start-km=2 "${COMMON[@]}" --shot-times=1,3)
bash $AB "$NEW" "$O/fly_new" "modern" "${FLY[@]}"
bash $AB "$OLD" "$O/fly_old" "modern" "${FLY[@]}"
echo "== $(date -u +%T)"
for nn in 00 01; do
	echo "fly $nn: new $(md5sum < "$O/fly_new_modern_$nn.png" | cut -c1-12) old $(md5sum < "$O/fly_old_modern_$nn.png" | cut -c1-12) AE=$(compare -metric AE "$O/fly_new_modern_$nn.png" "$O/fly_old_modern_$nn.png" null: 2>&1)"
done
echo "== ende $(date -u +%T)"
echo QUEUEDONE
