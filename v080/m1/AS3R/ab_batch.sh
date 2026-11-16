#!/usr/bin/env bash
# AS3R: Arcade | Modern in the race (tools/ab_shot.sh) at stage positions where the AS3 sets stand, one after the other
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
cd "$WT"
mkdir -p $S/ab
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
run() {   # name preset screen args...
	local name=$1 preset=$2 screen=$3; shift 3
	local t0=$(date +%s)
	GFX_ARGS="--gfx-preset=$preset" SCREEN=$screen AB_TIMEOUT=900 nice -n 19 tools/ab_shot.sh "$S/ab/$name" "$@" $BASE > "$S/logs/ab_$name.log" 2>&1
	local rc=$?
	echo "$name exit $rc $(( $(date +%s) - t0 )) s  Fehlerzeilen modern: $(grep -cE 'SCRIPT ERROR|^ERROR' "$S/ab/${name}_modern.log" 2>/dev/null)  arcade: $(grep -cE 'SCRIPT ERROR|^ERROR' "$S/ab/${name}_arcade.log" 2>/dev/null)"
}
run kh54_hoch high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=53.9 --hour=12 --start-speed=120 --shot-times=2,2.6
run bm42_hoch high 1280x720 --stage=barcelona_montpellier --from=barcelona --start-km=42 --hour=12 --start-speed=120 --shot-times=2,2.6
run lb148_hoch high 1280x720 --stage=lyon_bern --from=lyon --start-km=148 --hour=12 --start-speed=120 --shot-times=2,2.6
run hh47_mittel medium 1280x720 --stage=hamburg_hannover --from=hamburg --start-km=47 --hour=12 --start-speed=120 --shot-times=2
run kh54_deck deck 1280x800 --stage=kiel_hamburg --from=kiel --start-km=53.9 --hour=12 --start-speed=120 --shot-times=2,2.6
echo AB_DONE
