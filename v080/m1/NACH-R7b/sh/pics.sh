#!/usr/bin/env bash
# NACH-R7b: picture triples, one run at a time. Skips what exists. GROUP=a|b
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7b
D=$S/raw
mkdir -p $D
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
one() {   # name preset screen args…
	local name=$1
	shift
	[ -s "$D/${name}_abc.jpg" ] && [ -z "${FORCE:-}" ] && return
	$S/sh/abc.sh "$D/$name" "$@" 2>&1 | tail -3
}
G=${GROUP:-a}
if [[ ",$G," == *",a,"* ]]; then
	one hamburg_22 high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=85.6 --hour=22 $COMMON
	one dortmund_22 high 1280x720 --stage=bremen_dortmund --from=bremen --start-km=225.0 --hour=22 $COMMON
	one deck_dortmund_22 deck 1280x800 --stage=bremen_dortmund --from=bremen --start-km=225.0 --hour=22 $COMMON
	one madrid_22 high 1280x720 --stage=burgos_madrid --from=burgos --start-km=228.0 --hour=22 $COMMON
fi
if [[ ",$G," == *",b,"* ]]; then
	one deck_hamburg_22 deck 1280x800 --stage=kiel_hamburg --from=kiel --start-km=85.6 --hour=22 $COMMON
	one nah_hannover_22 high 1280x720 --stage=hamburg_hannover --from=hamburg --start-km=146.0 --hour=22 $COMMON
	one bremerdom_22 high 1280x720 --stage=hamburg_bremen --from=hamburg --start-km=114.4 --hour=22 $COMMON
	one hamburg_12 high 1280x720 --stage=kiel_hamburg --from=kiel --start-km=85.6 --hour=12 $COMMON
fi
if [[ ",$G," == *",c,"* ]]; then
	one nah_calais_22 high 1280x720 --stage=bruessel_calais --from=bruessel --start-km=209.5 --hour=22 $COMMON
	one dortmund_22_t2 high 1280x720 --stage=bremen_dortmund --from=bremen --start-km=225.0 --hour=22 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1.5
fi
echo "FERTIG $G"
