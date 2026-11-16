#!/usr/bin/env bash
# AS5aR2: measurements and review pictures on the real exports, one heavy job after the other.
#   chain_meas.sh [steps]   steps: contact close dist lods spark lodcol outline tint mip texel
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
[ -d tools/kritik ] || $S/install_tools.sh > /dev/null
STEPS="${*:-contact close dist lods spark lodcol outline tint mip texel}"
B2="props/city_dutch_*,props/city_belgian_*,props/city_french_*,props/city_paris_*,props/city_swiss_*"
B1="props/city_german_*,props/city_hanse_*"
ALL12="props/city_dutch_canal,props/city_dutch_canal_b,props/city_dutch_terrace,props/city_belgian_terrace,props/city_belgian_stone,props/city_french_maison,props/city_french_sud,props/city_french_immeuble,props/city_paris_haussmann,props/city_paris_corner,props/city_swiss_chalet,props/city_swiss_laube"
G1="props/city_french_sud,props/city_french_maison,props/city_french_immeuble,props/city_belgian_terrace"
G2="props/city_belgian_stone,props/city_dutch_terrace,props/city_dutch_canal,props/city_dutch_canal_b"
G3="props/city_swiss_chalet,props/city_swiss_laube,props/city_paris_haussmann,props/city_paris_corner"
source $S/items.sh
B1I="props/city_german_gruenderzeit@21.0;props/city_german_mietshaus@26.6;props/city_hanse_kontor@27.4"
mkdir -p $S/shots/fin $S/logs/fin
for st in $STEPS; do
	echo "STEP $st $(date +%H:%M)"
	case $st in
	contact)
		for b in B2 B1; do
			waitmem
			nice -n 19 tools/models_contact_sheet.sh $S/shots/fin/kontakt_${b}_tag.png "--only=${!b}" --cols=4 > $S/logs/fin/contact_${b}_tag.log 2>&1
			echo "contact $b tag exit $?"
			nice -n 19 tools/models_contact_sheet.sh $S/shots/fin/kontakt_${b}_nacht.png "--only=${!b}" --cols=4 --night > $S/logs/fin/contact_${b}_nacht.log 2>&1
			echo "contact $b nacht exit $?"
		done ;;
	close)
		for g in FRA PAR SWI DUT BEL; do
			for h in 12 22; do
				$S/k5.sh k5_scene fin/close_${g}_h$h --mode=close "--items=${!g}" --views=road,oblique,front --look=race --hour=$h --preset=high | grep -c ERROR
			done
		done ;;
	dist)
		for g in FRA PAR SWI DUT BEL B1I; do
			for h in 12 19.5 22; do
				$S/k5.sh k5_scene fin/dist_${g}_h$h --mode=dist2 "--items=${!g}" --dist=10,30,100,250 --sprite --look=race --hour=$h --preset=high --tile=480x400 | grep -c ERROR
			done
		done ;;
	lods)
		for g in G1 G2 G3; do
			for h in 12 22; do
				$S/k5.sh k5_scene fin/lods_${g}_h$h --mode=lods "--models=${!g}" --sprite --x=20 --look=race --hour=$h --preset=medium | grep -E "UMSCHALT|STUFE"
			done
		done ;;
	spark)
		$S/k5.sh my_scene fin/spark --mode=sparkcam "--models=props/city_paris_haussmann,props/city_paris_corner,props/city_dutch_canal_b,props/city_french_maison,props/city_french_sud,props/city_swiss_laube" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium | grep -E "FLIMMER|SPARK" ;;
	lodcol)
		for h in 12 22; do
			$S/k5.sh k6_scene fin/lodcol_h$h --mode=lodcol "--models=$ALL12" --dists=60,120,250 --x=20 --sprite --look=race --hour=$h --preset=high --tile=320x260 | grep -E "LODCOL" > $S/logs/fin/lodcol_h$h.log
			wc -l < $S/logs/fin/lodcol_h$h.log
		done ;;
	outline)
		$S/k5.sh k4_scene fin/outline --mode=outline2 "--items=props/city_french_sud;props/city_belgian_terrace;props/city_french_maison;props/city_french_immeuble;props/city_dutch_terrace;props/city_belgian_stone;props/city_paris_haussmann;props/city_swiss_chalet;props/city_dutch_canal;props/city_swiss_laube;props/city_dutch_canal_b;props/city_paris_corner" --look=race --hour=12 --preset=high | grep UMRISS ;;
	tint)
		I=$(python3 $S/py_items.py $WT city_dutch_terrace)
		$S/k5.sh tint_scene fin/tint --mode=tint "--items=$I#ead6cc" --dist=40 --look=race --hour=12 --preset=high --tile=480x400 | tail -2 ;;
	mip)
		python3 $S/tools/mipband.py "#8f8676" assets/models/props/city_paris_haussmann/albedo.webp assets/models/props/city_paris_corner/albedo.webp > $S/logs/fin/mipband.log 2>&1
		python3 $S/tools/mipband.py "#6f6250" assets/models/props/city_french_immeuble/albedo.webp >> $S/logs/fin/mipband.log 2>&1
		python3 $S/tools/mipband.py "#b08a68" assets/models/props/city_french_sud/albedo.png >> $S/logs/fin/mipband.log 2>&1
		python3 $S/tools/mipband.py "#6a4a32" assets/models/props/city_swiss_chalet/albedo.png >> $S/logs/fin/mipband.log 2>&1
		python3 $S/tools/mipcov.py assets/models/props/city_paris_haussmann/albedo.webp assets/models/props/city_french_immeuble/albedo.webp assets/models/props/city_french_sud/albedo.png assets/models/props/city_swiss_chalet/albedo.png >> $S/logs/fin/mipband.log 2>&1
		cat $S/logs/fin/mipband.log ;;
	texel)
		K5_OUTER=4.5 timeout 600 nice -n 19 godot --headless --path . -s res://tools/kritik/texel_k5.gd -- --models=$ALL12 2>&1 | grep TEXEL > $S/logs/fin/texel.log
		cat $S/logs/fin/texel.log ;;
	esac
done
echo "=== chain_meas fertig $(date +%H:%M)"
