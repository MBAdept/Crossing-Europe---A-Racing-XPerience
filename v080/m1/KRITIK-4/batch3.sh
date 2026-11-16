#!/usr/bin/env bash
# KRITIK-4 batch 3: Arcade | Modern in the race (tools/ab_shot.sh in the scratch copy) where AS4 sets stand.
# Waits for batch 2. One run after the other, nice 19. Progress in $K/logs/batch3.log
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4
L=$K/logs/batch3.log
: > "$L"
until grep -q BATCH2_DONE $K/logs/batch2.log 2>/dev/null; do sleep 10; done
source $K/env.sh
export MESA_SHADER_CACHE_DIR=$K/mesa_ab
mkdir -p "$MESA_SHADER_CACHE_DIR" "$K/ab"
cd "$T"
BASE="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
run() {   # name preset screen args...
	local name=$1 preset=$2 screen=$3; shift 3
	local t0=$(date +%s)
	GFX_ARGS="--gfx-preset=$preset" SCREEN=$screen AB_TIMEOUT=1200 nice -n 19 tools/ab_shot.sh "$K/ab/$name" "$@" $BASE > "$K/logs/ab_$name.log" 2>&1
	echo "$name exit $? $(( $(date +%s) - t0 )) s  Fehler modern: $(grep -cE 'SCRIPT ERROR|Parse Error|SHADER ERROR' "$K/ab/${name}_modern.log" 2>/dev/null)" >> "$L"
}
run pylon_mittag high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=77.4 --hour=12 --start-speed=50 --shot-times=1,2.5,4,6
run dorf_mittag high 1280x720 --stage=paris_tours --from=paris --start-km=129.0 --hour=12 --start-speed=100 --shot-times=1,6,9
run dorf_nacht high 1280x720 --stage=paris_tours --from=paris --start-km=129.0 --hour=23 --start-speed=100 --shot-times=1,6,9
run altstadt_abend medium 1280x720 --stage=kassel_wuerzburg --from=kassel --start-km=201.2 --hour=21 --start-speed=60 --shot-times=2,6,10
run hausboote_mittag high 1280x720 --stage=bremen_amsterdam --from=bremen --start-km=356.6 --hour=12 --start-speed=60 --shot-times=2,6
run stadt_deck deck 1280x800 --stage=hamburg_hannover --from=hamburg --start-km=141.9 --hour=12 --start-speed=80 --shot-times=2,5
run turm_nachmittag high 1280x720 --stage=dresden_leipzig --from=dresden --start-km=111.0 --hour=15 --start-speed=100 --shot-times=2,5
run fabrik_nacht high 1280x720 --stage=bremen_dortmund --from=dortmund --start-km=1.9 --hour=23 --start-speed=100 --shot-times=1,3
echo BATCH3_DONE >> "$L"
