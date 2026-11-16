#!/usr/bin/env bash
# AS5a2: measurements and review pictures on the real exports (after chain_b1), one heavy job after the other.
#   chain_meas.sh [steps]   steps: validate contact lods spark outline tint mip
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
source $S/env.sh
if [ -z "${NOWAIT:-}" ]; then
	until grep -q "=== chain_b1 fertig" $S/logs/chain_b1.out 2>/dev/null; do sleep 30; done
fi
cd $WT
STEPS="${*:-validate contact lods spark outline tint mip}"
MINE="props/city_dutch_*,props/city_belgian_*,props/city_french_*,props/city_paris_*,props/city_swiss_*"
G1="props/city_french_sud,props/city_french_maison,props/city_french_immeuble,props/city_belgian_terrace"
G2="props/city_belgian_stone,props/city_dutch_terrace,props/city_dutch_canal,props/city_dutch_canal_b"
G3="props/city_swiss_chalet,props/city_swiss_laube,props/city_paris_haussmann,props/city_paris_corner"
mkdir -p $S/shots/fin $S/logs/fin
for st in $STEPS; do
	echo "STEP $st $(date +%H:%M)"
	case $st in
	validate)
		python3 tools/blender/validate_models.py --report > $S/logs/fin/validate.log 2>&1
		echo "validate exit $?: $(grep -E 'CHECK|FEHLER' $S/logs/fin/validate.log | head -5 | tr '\n' ' ')" ;;
	contact)
		waitmem
		nice -n 19 tools/models_contact_sheet.sh $S/shots/fin/kontakt_tag.png "--only=$MINE" --cols=4 > $S/logs/fin/contact_tag.log 2>&1
		echo "contact tag exit $?"
		nice -n 19 tools/models_contact_sheet.sh $S/shots/fin/kontakt_nacht.png "--only=$MINE" --cols=4 --night > $S/logs/fin/contact_nacht.log 2>&1
		echo "contact nacht exit $?" ;;
	lods)
		for g in G1 G2 G3; do
			for h in 12 22; do
				$S/k5.sh k5_scene fin/lods_${g}_h$h --mode=lods "--models=${!g}" --sprite --x=20 --look=race --hour=$h --preset=medium | grep UMSCHALT
			done
		done ;;
	spark)
		$S/k5.sh k5_scene fin/spark --mode=sparkcam "--models=props/city_paris_haussmann,props/city_dutch_canal,props/city_belgian_terrace,props/city_french_immeuble,props/city_swiss_chalet" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium | grep -E "FLIMMER|SPARK" ;;
	outline)
		I=$(python3 $S/py_items.py $WT city_french_sud,city_belgian_terrace,city_french_maison,city_french_immeuble,city_dutch_terrace,city_belgian_stone,city_paris_haussmann,city_swiss_chalet,city_dutch_canal,city_swiss_laube,city_dutch_canal_b,city_paris_corner)
		$S/k5.sh k5_scene fin/outline --mode=outline2 "--items=$I" --look=race --hour=12 --preset=high | grep UMRISS ;;
	tint)
		I=$(python3 $S/py_items.py $WT city_dutch_terrace)
		$S/k5.sh tint_scene fin/tint --mode=tint "--items=$I#ead6cc" --dist=40 --look=race --hour=12 --preset=high --tile=480x400 | tail -2 ;;
	mip)
		python3 $S/tools/mipband.py "#8f8676" assets/models/props/city_paris_haussmann/albedo.webp assets/models/props/city_paris_corner/albedo.webp > $S/logs/fin/mipband.log 2>&1
		python3 $S/tools/mipband.py "#6f6250" assets/models/props/city_french_immeuble/albedo.webp >> $S/logs/fin/mipband.log 2>&1
		python3 $S/tools/mipband.py "#b08a68" assets/models/props/city_french_sud/albedo.png >> $S/logs/fin/mipband.log 2>&1
		python3 $S/tools/mipband.py "#6a4a32" assets/models/props/city_swiss_chalet/albedo.png >> $S/logs/fin/mipband.log 2>&1
		tail -30 $S/logs/fin/mipband.log ;;
	esac
done
echo "=== chain_meas fertig $(date +%H:%M)"
