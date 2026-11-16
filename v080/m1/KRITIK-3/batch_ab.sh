#!/usr/bin/env bash
# KRITIK-3: Arcade | Modern in the race at stage positions with AS3 species (tools/ab_shot.sh), one after the other
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-3/env.sh
until grep -q EXTRA_DONE $K/logs/batch_extra.log; do sleep 15; done
cd "$T"
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
run() {   # name preset screen args...
	local name=$1 preset=$2 screen=$3; shift 3
	local t0=$(date +%s)
	GFX_ARGS="--gfx-preset=$preset" SCREEN=$screen AB_TIMEOUT=900 nice -n 19 tools/ab_shot.sh "$K/ab/$name" "$@" $BASE > "$K/logs/ab_$name.log" 2>&1
	echo "$name exit $? $(( $(date +%s) - t0 )) s  Fehler modern: $(grep -cE 'SCRIPT ERROR|^ERROR' "$K/ab/${name}_modern.log" 2>/dev/null)"
}
run kh54_hoch high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=53.9 --hour=12 --start-speed=120 --shot-times=2,2.6
run kh54_deck deck 1280x800 --stage=kiel_hamburg --from=kiel --start-km=53.9 --hour=12 --start-speed=120 --shot-times=2,2.6
run kh54_daemmerung medium 1280x720 --stage=kiel_hamburg --from=kiel --start-km=53.9 --hour=19.5 --start-speed=120 --shot-times=2,2.6
run kh54_nacht medium 1280x720 --stage=kiel_hamburg --from=kiel --start-km=53.9 --hour=23 --start-speed=120 --shot-times=2,2.6
run kh_stadt_hoch high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=92.2 --hour=12 --start-speed=50 --shot-times=2,3
run mv60_hoch high 1280x720 --stage=mailand_venedig --from=mailand --start-km=60 --hour=12 --start-speed=120 --shot-times=2,2.6
run df121_hoch high 1280x720 --stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=12 --start-speed=120 --shot-times=2,2.6
run lb_klippe_hoch high 1280x720 --stage=lyon_bern --from=lyon --start-km=143.3 --hour=12 --start-speed=120 --shot-times=1.2,2,2.6
echo AB_DONE
