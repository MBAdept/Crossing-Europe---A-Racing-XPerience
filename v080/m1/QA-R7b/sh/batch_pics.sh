#!/usr/bin/env bash
# QA-R7b: all picture triples (Arcade | base | head), one run at a time. Skips what exists. GROUP= arr|near|deck|sky
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R7b/raw
mkdir -p $D
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
ARR="hamburg:kiel_hamburg:kiel:85.6
dortmund:bremen_dortmund:bremen:225.0
belgrad:slavonski_brod_belgrad:slavonski_brod:196.6
madrid:burgos_madrid:burgos:228.0
hannover:hamburg_hannover:hamburg:142.5
leipzig:dresden_leipzig:dresden:103.0
paris:luettich_paris:luettich:388.7
bruessel:koeln_bruessel:koeln:206.4
calais:bruessel_calais:bruessel:206.0
nuernberg:wuerzburg_nuernberg:wuerzburg:102.0"
NEAR="hannover:hamburg_hannover:hamburg:146.0
leipzig:dresden_leipzig:dresden:106.5
belgrad:slavonski_brod_belgrad:slavonski_brod:200.0
calais:bruessel_calais:bruessel:209.5
madrid:burgos_madrid:burgos:231.5
nuernberg:wuerzburg_nuernberg:wuerzburg:105.5
paris:luettich_paris:luettich:392.2"
one() {   # name preset screen args…
	for q in $S/queue/*.sh; do
		[ -f "$q" ] || continue
		mv "$q" "$q.run"
		bash "$q.run" >> $S/queue.log 2>&1
	done
	local name=$1
	shift
	[ -s "$D/${name}_abc.jpg" ] && [ -z "${FORCE:-}" ] && return
	$S/sh/abc.sh "$D/$name" "$@" 2>&1 | tail -3
}
G=${GROUP:-arr,near,flood,deck,sky,dusk}
if [[ ",$G," == *",arr,"* ]]; then
	for h in ${ARR_HOURS:-12 22}; do
		for line in $ARR; do
			IFS=: read -r name stage from km <<<"$line"
			one "${name}_$(echo $h | tr -d .)" high 1280x720 --stage=$stage --from=$from --start-km=$km --hour=$h $COMMON
		done
	done
fi
if [[ ",$G," == *",near,"* ]]; then
	for h in 12 22; do
		for line in $NEAR; do
			IFS=: read -r name stage from km <<<"$line"
			one "nah_${name}_$h" high 1280x720 --stage=$stage --from=$from --start-km=$km --hour=$h $COMMON
		done
	done
fi
if [[ ",$G," == *",deck,"* ]]; then
	for h in 12 22; do
		for line in $(echo "$ARR" | head -2) $(echo "$NEAR" | sed -n 3p); do
			IFS=: read -r name stage from km <<<"$line"
			one "deck_${name}_${km}_$h" deck 1280x800 --stage=$stage --from=$from --start-km=$km --hour=$h $COMMON
		done
	done
fi
if [[ ",$G," == *",sky,"* ]]; then
	for s in 2 13.6 60 80 94; do
		sp=120
		[ "$s" = "80" ] && sp=50
		one "skyline_km$s" high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=$s --hour=12 --weather=normal --vehicle=limousine \
			--seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=$sp --shot-times=2
	done
	one "skyline_kassel" high 1280x720 --stage=hannover_kassel --from=hannover --start-km=148.5 --hour=12 $COMMON
	one "skyline_kassel_22" high 1280x720 --stage=hannover_kassel --from=hannover --start-km=148.5 --hour=22 $COMMON
	one "skyline_koeln_12" high 1280x720 --stage=koeln_bruessel --from=bruessel --start-km=214.6 --hour=12 $COMMON
	one "skyline_koeln_22" high 1280x720 --stage=koeln_bruessel --from=bruessel --start-km=214.6 --hour=22 $COMMON
	one "skyline_riga_12" high 1280x720 --stage=kaunas_riga --from=kaunas --start-km=254.6 --hour=12 $COMMON
fi
if [[ ",$G," == *",flood,"* ]]; then
	# plain props standing as landmarks (props/church model, floodlit at night in Arcade)
	for h in 22 12; do
		one "flood_bremen_$h" high 1280x720 --stage=hamburg_bremen --from=hamburg --start-km=118.0 --hour=$h $COMMON
		one "flood_slavonski_$h" high 1280x720 --stage=slavonski_brod_belgrad --from=belgrad --start-km=202.8 --hour=$h $COMMON
	done
fi
if [[ ",$G," == *",flood2,"* ]]; then
	# 400 m before (1 stage-km = 100 m of road)
	for h in 22 12; do
		one "flood2_bremen_$h" high 1280x720 --stage=hamburg_bremen --from=hamburg --start-km=114.4 --hour=$h $COMMON
		one "flood2_slavonski_$h" high 1280x720 --stage=slavonski_brod_belgrad --from=belgrad --start-km=199.2 --hour=$h $COMMON
	done
fi
if [[ ",$G," == *",dusk,"* ]]; then
	for line in $ARR; do
		IFS=: read -r name stage from km <<<"$line"
		one "${name}_195" high 1280x720 --stage=$stage --from=$from --start-km=$km --hour=19.5 $COMMON
	done
fi
echo PICS_DONE
