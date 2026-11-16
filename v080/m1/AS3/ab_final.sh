#!/usr/bin/env bash
# AS3 scratch: A/B Arcade | Modern on the final head (preset high, noon) at the three nature positions of the census
# plus the Alps (spruce) – one run after the other, nice 19
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120 --shot-times=2"
declare -A POS
POS[heide]="--stage=hamburg_hannover --from=hamburg --start-km=47"
POS[mittelmeer]="--stage=barcelona_montpellier --from=barcelona --start-km=42"
POS[pyrenaeen]="--stage=saragossa_pau --from=saragossa --start-km=152"
POS[alpen]="--stage=lyon_bern --from=lyon --start-km=148"
for job in "alpen high 12" "heide high 12" "mittelmeer high 12" "pyrenaeen high 12" "alpen medium 19.5"; do
	set -- $job
	name="fin_${1}_${2}_${3}"
	echo "=== $name $(date +%H:%M:%S)"
	# shellcheck disable=SC2086
	GFX_ARGS="--gfx-preset=$2" nice -n 19 tools/ab_shot.sh "$S/shots/$name" ${POS[$1]} --hour=$3 $BASE > "$S/logs/$name.log" 2>&1
	echo "$name exit $?: $(grep -cE 'SCRIPT ERROR|ERROR' "$S/shots/${name}_modern.log" 2>/dev/null) Fehlerzeilen Modern, $(grep -cE 'SCRIPT ERROR|ERROR' "$S/shots/${name}_arcade.log" 2>/dev/null) Arcade"
done
echo "=== fertig $(date +%H:%M:%S)"
