#!/bin/bash
# QA-R7c master queue 3 (after q2): core pictures -> perf -> render mutations -> remaining pictures -> golden check.
# Restart-safe: tri.sh skips existing pictures, perf/mutation steps skip when their log has a result line.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
until grep -q "Q2 DONE" "$S/logs/q2.out" 2>/dev/null; do sleep 30; done
echo "Q3 start $(date -u +%H:%M:%S)" >> "$S/logs/q3.out"
declare -A POS
POS[pa]="--stage=luettich_paris --from=luettich --start-km=387.5"
POS[am]="--stage=bremen_amsterdam --from=bremen --start-km=357.3"
POS[ly_out]="--stage=montpellier_lyon --from=montpellier --start-km=285.6"
POS[be]="--stage=lyon_bern --from=lyon --start-km=302.3"
POS[hh]="--stage=kiel_hamburg --from=kiel --start-km=88.2"
POS[nu]="--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.0"
POS[wald]="--stage=dortmund_frankfurt --from=dortmund --start-km=48.0"
OUTD=$D/raw
mkdir -p "$OUTD"
one() {   # one <name> <preset> <hour>
	local n=$1 q=$2 h=$3
	local spd=50
	[ "$n" = "wald" ] && spd=120
	local scr=1280x720
	[ "$q" = "deck" ] && scr=1280x800
	# shellcheck disable=SC2086
	SCREEN=$scr MERGE=${MERGE:-0} "$S/sh/tri.sh" "$OUTD/${n}_${q}_h${h}" "$q" ${POS[$n]} --hour=$h --weather=normal --vehicle=limousine --seed=11 \
		--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=$spd --shot-times=${SHOTS:-2,4}
	echo "$(date -u +%H:%M:%S) done $n $q $h" >> "$S/logs/q3.out"
}
# --- core pictures
for n in hh nu pa am be ly_out; do MERGE=1 one $n high 12; done
for n in hh nu; do MERGE=1 one $n deck 12; done
one wald high 12
one wald deck 12
MERGE=1 one pa high 22
one hh high 22
one nu high 22
one hh high 19.5
echo "Q3 core pictures done $(date -u +%H:%M:%S)" >> "$S/logs/q3.out"
# --- perf
"$S/sh/perf.sh"
echo "Q3 perf done $(date -u +%H:%M:%S)" >> "$S/logs/q3.out"
# --- render mutations (+ baseline of check_lod_band in the unmodified mutation copy)
python3 "$S/sh/mutate.py" R1_no_dither R2_shadow_dithers R3_far_light_off R4_window_cover_off >> "$S/logs/q3.out" 2>&1
echo "Q3 render mutations done $(date -u +%H:%M:%S)" >> "$S/logs/q3.out"
# --- remaining pictures
for n in pa am be ly_out; do one $n deck 12; done
for n in pa nu; do one $n high 19.5; done
for n in am be ly_out; do one $n high 22; done
one hh deck 22
one pa deck 22
one hh deck 19.5
one wald deck 22
echo "Q3 pictures done $(date -u +%H:%M:%S)" >> "$S/logs/q3.out"
# --- Arcade identity, once at the end
cd "$WT" && XDG_DATA_HOME=$S/xdg_golden nice -n 10 tools/golden.sh check > "$S/gates/golden_check.log" 2>&1
echo "$(date -u +%H:%M:%S) golden exit=$?" >> "$S/logs/q3.out"
echo "Q3 DONE $(date -u +%H:%M:%S)" >> "$S/logs/q3.out"
