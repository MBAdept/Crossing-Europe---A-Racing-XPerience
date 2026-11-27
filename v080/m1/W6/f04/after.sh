#!/bin/bash
# F-04 after the export: wait for the HUD gates and the export, bake the 23 AS5a houses, import, manifest, validate,
# then the night A/B pictures of the six city positions (same arguments as the baseline f04/*22) -> f04/after/
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
L=$S/logs/f04.log
until grep -q "GATES HUD2 DONE" $S/logs/gates.log && grep -q "F04 EXPORT DONE" $L; do sleep 30; done
cd $WT
IDS="props/city_german_house props/city_german_mietshaus props/city_german_gruenderzeit props/city_german_office
	props/city_german_old_fachwerk props/city_german_old_fachwerk_b props/city_german_old_barock props/city_hanse_gabled
	props/city_hanse_kontor props/city_hanse_speicher props/city_hanse_crane props/city_french_sud props/city_belgian_terrace
	props/city_french_maison props/city_french_immeuble props/city_dutch_terrace props/city_belgian_stone
	props/city_paris_haussmann props/city_swiss_chalet props/city_dutch_canal props/city_swiss_laube props/city_dutch_canal_b
	props/city_paris_corner"
if [ ! -f $S/f04/bake.done ]; then
	for id in $IDS; do
		nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" > $S/logs/f04_bake_$(basename $id).log 2>&1
		echo "$(date +%T) BAKE $id rc $? $(grep -E 'Modelle|FEHLER|ERROR' $S/logs/f04_bake_$(basename $id).log | tail -1)" >> $L
	done
	nice -n 10 godot --headless --path . --import > $S/logs/f04_import.log 2>&1
	nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only > $S/logs/f04_manifest.log 2>&1
	echo "$(date +%T) MANIFEST rc $? $(tail -1 $S/logs/f04_manifest.log)" >> $L
	nice -n 10 python3 tools/blender/validate_models.py > $S/logs/f04_validate.log 2>&1
	echo "$(date +%T) VALIDATE rc $? $(tail -1 $S/logs/f04_validate.log)" >> $L
	touch $S/f04/bake.done
fi
mkdir -p $S/f04/after
declare -A POS
POS[pa]="--stage=luettich_paris --from=luettich --start-km=387.5"
POS[am]="--stage=bremen_amsterdam --from=bremen --start-km=357.3"
POS[br]="--stage=koeln_bruessel --from=koeln --start-km=195.5"
POS[ly]="--stage=montpellier_lyon --from=montpellier --start-km=297.0"
POS[be]="--stage=lyon_bern --from=lyon --start-km=302.3"
COMMON="--hour=22 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --gfx-preset=high --shot-times=2,4"
for n in pa am br ly be; do
	[ -f $S/f04/after/${n}22_modern_01.png ] && continue
	waitmem
	nice -n 10 tools/ab_shot.sh $S/f04/after/${n}22 ${POS[$n]} $COMMON > $S/f04/after/${n}22.log 2>&1 < /dev/null
	echo "$(date +%T) AB $n exit $?" >> $L
done
if [ ! -f $S/f04/after/khh22_modern_01.png ]; then
	nice -n 10 tools/ab_shot.sh $S/f04/after/khh22 S4 --hour=22 --gfx-preset=high --shot-times=2,4 > $S/f04/after/khh22.log 2>&1 < /dev/null
	echo "$(date +%T) AB khh exit $?" >> $L
fi
python3 $S/f04/warm_ab.py $S/f04/after/pa22 $S/f04/after/am22 $S/f04/after/br22 $S/f04/after/ly22 $S/f04/after/be22 $S/f04/after/khh22 > $S/f04/after/warm.txt 2>&1
echo "$(date +%T) F04 AFTER DONE" >> $L
