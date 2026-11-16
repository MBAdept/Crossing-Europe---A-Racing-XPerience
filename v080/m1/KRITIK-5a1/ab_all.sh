#!/usr/bin/env bash
# KRITIK-5a1: A/B Arcade|Modern in the race at the city arrivals.  ab_all.sh "<pos>:<preset>:<hour> ..."
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
source $K/env.sh
cd "$T"
mkdir -p $K/ab
declare -A POS
POS[ho]="--stage=kiel_hamburg --from=kiel --start-km=81.2"
POS[hh]="--stage=kiel_hamburg --from=kiel --start-km=88.2"
POS[hn]="--stage=hamburg_hannover --from=hamburg --start-km=143.9"
POS[ks]="--stage=hannover_kassel --from=hannover --start-km=157.4"
POS[wu]="--stage=kassel_wuerzburg --from=kassel --start-km=202.9"
POS[nu]="--stage=wuerzburg_nuernberg --from=wuerzburg --start-km=102.7"
POS[mu]="--stage=muenchen_nuernberg --from=nuernberg --start-km=161.7"
for job in $1; do
	IFS=: read -r n p h <<< "$job"
	waitmem
	pre="$K/ab/${n}_${p}_h${h}"
	start=$(date +%s)
	AB_TIMEOUT=1500 GFX_ARGS="--gfx-preset=$p" nice -n 19 tools/ab_shot.sh "$pre" ${POS[$n]} --hour=$h --weather=normal \
		--vehicle=limousine --seed=11 --autopilot --traffic-warmup --no-countdown --start-speed=50 \
		--shot-times=${SHOTS:-2,4} > "$pre.run.log" 2>&1
	code=$?
	errs=$(cat "${pre}_modern.log" "${pre}_arcade.log" 2>/dev/null | grep -c -E "SCRIPT ERROR|Parse Error|ERROR:")
	echo "AB $n $p h$h exit $code Fehlerzeilen $errs $(( $(date +%s) - start )) s"
done
echo "=== ab_all fertig $(date +%H:%M)"
