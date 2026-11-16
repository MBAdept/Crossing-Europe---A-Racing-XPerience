#!/usr/bin/env bash
# AS3 scratch: A/B pictures at the three nature positions, presets high / medium, noon / dusk (one run at a time)
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120 --shot-times=2"
declare -A POS
POS[heide]="--stage=hamburg_hannover --from=hamburg --start-km=47"
POS[mittelmeer]="--stage=barcelona_montpellier --from=barcelona --start-km=42"
POS[pyrenaeen]="--stage=saragossa_pau --from=saragossa --start-km=152"
for p in heide mittelmeer pyrenaeen; do
	for preset in high medium; do
		for h in 12 19.5; do
			name="ab_${p}_${preset}_${h}"
			# shellcheck disable=SC2086
			GFX_ARGS="--gfx-preset=$preset" nice -n 19 tools/ab_shot.sh "$S/shots/$name" ${POS[$p]} --hour=$h $BASE > "$S/logs/$name.log" 2>&1
			echo "$name exit $?: $(grep -cE 'SCRIPT ERROR|ERROR' "$S/shots/${name}_modern.log" 2>/dev/null) Fehlerzeilen"
		done
	done
done
echo "=== fertig"
