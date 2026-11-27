#!/bin/bash
# F-04: night A/B of the AS5a city positions (AS5aR2 ab_all.sh), 22:00, Hoch, shots at 2 and 4 s
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
cd $WT
declare -A POS
POS[pa]="--stage=luettich_paris --from=luettich --start-km=387.5"
POS[am]="--stage=bremen_amsterdam --from=bremen --start-km=357.3"
POS[br]="--stage=koeln_bruessel --from=koeln --start-km=195.5"
POS[ly]="--stage=montpellier_lyon --from=montpellier --start-km=297.0"
POS[be]="--stage=lyon_bern --from=lyon --start-km=302.3"
for n in pa am br ly be; do
	[ -f $W6/f04/${n}22_modern_01.png ] && continue
	waitmem
	nice -n 10 tools/ab_shot.sh $W6/f04/${n}22 ${POS[$n]} --hour=22 --weather=normal --vehicle=limousine --seed=11 \
		--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --gfx-preset=high \
		--shot-times=2,4 > $W6/f04/${n}22.log 2>&1 < /dev/null
	echo "$(date +%T) AB $n exit $?" >> $W6/logs/f04.log
done
echo "AB F04 DONE $(date +%T)" >> $W6/logs/f04.log
