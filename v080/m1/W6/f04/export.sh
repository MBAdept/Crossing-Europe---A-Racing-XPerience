#!/bin/bash
# F-04: Blender export (step 1, only tools/blender/_cache3d) of the 23 AS5a houses with lit_k; bake later
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
export CE_THREADS=3
cd $WT
for id in props/city_german_house props/city_german_mietshaus props/city_german_gruenderzeit props/city_german_office \
	props/city_german_old_fachwerk props/city_german_old_fachwerk_b props/city_german_old_barock props/city_hanse_gabled \
	props/city_hanse_kontor props/city_hanse_speicher props/city_hanse_crane props/city_french_sud props/city_belgian_terrace \
	props/city_french_maison props/city_french_immeuble props/city_dutch_terrace props/city_belgian_stone \
	props/city_paris_haussmann props/city_swiss_chalet props/city_dutch_canal props/city_swiss_laube props/city_dutch_canal_b \
	props/city_paris_corner; do
	n=$(basename $id)
	[ -f $S/f04/exp_$n.done ] && continue
	waitmem
	t0=$(date +%s)
	nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 > $S/logs/f04_exp_$n.log 2>&1
	rc=$?
	echo "$(date +%T) EXPORT $id rc $rc $(( $(date +%s) - t0 )) s: $(grep -E '^EXPORT|Traceback|Error' $S/logs/f04_exp_$n.log | grep -v CUEW | tail -2 | tr '\n' ' ')" >> $S/logs/f04.log
	[ $rc -eq 0 ] && touch $S/f04/exp_$n.done
done
echo "$(date +%T) F04 EXPORT DONE" >> $S/logs/f04.log
