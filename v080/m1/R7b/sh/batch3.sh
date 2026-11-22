#!/usr/bin/env bash
# R7b: near views (about 250 m) of the six procedural landmarks (3D shapes) and two pictures (Kaiserburg, Eiffel tower)
# at 12:00 and 22:00.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7b/ab_nah
mkdir -p "$D"
until grep -q BATCH2_DONE $S/batch2.log; do sleep 20; done
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
export GFX_ARGS="--gfx-preset=high"
CITIES="calais:bruessel_calais:bruessel:209.5
hannover:hamburg_hannover:hamburg:146.0
leipzig:dresden_leipzig:dresden:106.5
madrid:burgos_madrid:burgos:231.5
belgrad:slavonski_brod_belgrad:slavonski_brod:200.0
dortmund:bremen_dortmund:bremen:228.5
nuernberg:wuerzburg_nuernberg:wuerzburg:105.5
paris:luettich_paris:luettich:392.2"
for line in $CITIES; do
	IFS=: read -r name stage from km <<<"$line"
	for h in 12 22; do
		[ -f "$D/${name}_nah_${h}_ab_00.jpg" ] && continue
		echo "== $name nah $h"
		$S/sh/ab.sh "$D/${name}_nah_${h}" --stage=$stage --from=$from --start-km=$km --hour=$h $COMMON 2>&1 | tail -2
	done
done
echo BATCH3_DONE
