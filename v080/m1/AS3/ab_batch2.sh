#!/usr/bin/env bash
# AS3 scratch: the remaining A/B pictures (the machine is shared: high at noon and medium at dusk per position)
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
while pgrep -f "ab_shot.sh $S/shots/ab_heide_high_19.5" > /dev/null; do sleep 5; done
echo "ab_heide_high_19.5 fertig"
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120 --shot-times=2"
declare -A POS
POS[heide]="--stage=hamburg_hannover --from=hamburg --start-km=47"
POS[mittelmeer]="--stage=barcelona_montpellier --from=barcelona --start-km=42"
POS[pyrenaeen]="--stage=saragossa_pau --from=saragossa --start-km=152"
for job in "mittelmeer high 12" "pyrenaeen high 12" "mittelmeer medium 19.5" "pyrenaeen medium 19.5" "heide medium 12"; do
	set -- $job
	name="ab_${1}_${2}_${3}"
	# shellcheck disable=SC2086
	GFX_ARGS="--gfx-preset=$2" nice -n 19 tools/ab_shot.sh "$S/shots/$name" ${POS[$1]} --hour=$3 $BASE > "$S/logs/$name.log" 2>&1
	echo "$name exit $?: $(grep -cE 'SCRIPT ERROR|ERROR' "$S/shots/${name}_modern.log" 2>/dev/null) Fehlerzeilen"
done
echo "=== fertig"
