#!/usr/bin/env bash
# R7c: A/B Arcade|Modern at city arrivals.  ab_all.sh <outdir> "<name:preset:hour> ..."  (SHOTS=2,4 default)
# MODERN_ONLY=1: only the Modern run (Arcade pictures of the same state come from an earlier call)
set -uo pipefail
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
export AB_TIMEOUT=${AB_TIMEOUT:-2700}
cd "$WT"
OUT="$1"; RUNS="$2"
mkdir -p "$OUT"
declare -A POS
POS[pa]="--stage=luettich_paris --from=luettich --start-km=387.5"
POS[am]="--stage=bremen_amsterdam --from=bremen --start-km=357.3"
POS[br]="--stage=koeln_bruessel --from=koeln --start-km=195.5"
POS[ly]="--stage=montpellier_lyon --from=montpellier --start-km=297.0"
POS[ly_out]="--stage=montpellier_lyon --from=montpellier --start-km=285.6"
POS[be]="--stage=lyon_bern --from=lyon --start-km=302.3"
POS[hh]="--stage=kiel_hamburg --from=kiel --start-km=88.2"
POS[nu]="--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.0"
POS[wald]="--stage=dortmund_frankfurt --from=dortmund --start-km=48.0"
for r in $RUNS; do
	IFS=: read -r n p h <<< "$r"
	pre="$OUT/${n}_${p}_h${h}"
	[ -f "${pre}_ab_01.jpg" ] && continue
	waitmem
	st=$(date +%s)
	spd=50
	[ "$n" = "wald" ] && spd=120
	GFX_ARGS="--gfx-preset=$p" nice -n 10 tools/ab_shot.sh "$pre" ${POS[$n]} --hour=$h --weather=normal \
		--vehicle=limousine --seed=11 --autopilot --traffic-warmup --no-countdown --start-speed=$spd \
		--shot-times=${SHOTS:-2,4} > "$pre.run.log" 2>&1
	code=$?
	errs=$(cat "${pre}_modern.log" "${pre}_arcade.log" 2>/dev/null | grep -c -E "SCRIPT ERROR|Parse Error|ERROR:|SHADER ERROR")
	echo "AB $n $p h$h exit $code Fehlerzeilen $errs $(( $(date +%s) - st )) s $(date +%H:%M)"
done
echo "=== ab_all fertig $(date +%H:%M)"
