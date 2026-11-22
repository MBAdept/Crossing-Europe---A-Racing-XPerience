#!/usr/bin/env bash
# R7b: A/B pictures of ten city arrivals at 12:00, 19:30, 22:00 (+ Kassel skyline, S1–S5). One run at a time.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7b/ab
mkdir -p "$D"
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
export GFX_ARGS="--gfx-preset=high"
# name stage from start_km (main landmark about 600 m ahead)
CITIES="belgrad:slavonski_brod_belgrad:slavonski_brod:196.6
dortmund:bremen_dortmund:bremen:225.0
calais:bruessel_calais:bruessel:206.0
madrid:burgos_madrid:burgos:228.0
hannover:hamburg_hannover:hamburg:142.5
leipzig:dresden_leipzig:dresden:103.0
hamburg:kiel_hamburg:kiel:85.6
paris:luettich_paris:luettich:388.7
bruessel:koeln_bruessel:koeln:206.4
nuernberg:wuerzburg_nuernberg:wuerzburg:102.0"
ONLY=${ONLY:-}
for line in $CITIES; do
	IFS=: read -r name stage from km <<<"$line"
	if [ -n "$ONLY" ] && [[ ",$ONLY," != *",$name,"* ]]; then continue; fi
	for h in 12 19.5 22; do
		tag=$(echo "$h" | tr -d .)
		[ -f "$D/${name}_${tag}_ab_00.jpg" ] && [ -z "${FORCE:-}" ] && continue
		echo "== $name $h"
		$S/sh/ab.sh "$D/${name}_${tag}" --stage=$stage --from=$from --start-km=$km --hour=$h $COMMON 2>&1 | tail -3
	done
done
if [ -z "$ONLY" ]; then
	[ -f "$D/kassel_skyline_ab_00.jpg" ] || $S/sh/ab.sh "$D/kassel_skyline" --stage=hannover_kassel --from=hannover --start-km=148.5 --hour=12 $COMMON 2>&1 | tail -3
	for s in S1 S2 S3 S4 S5; do
		[ -f "$D/skyline_${s}_ab_00.jpg" ] || $S/sh/ab.sh "$D/skyline_${s}" $s --shot-times=2 2>&1 | tail -3
	done
fi
echo BATCH_DONE
