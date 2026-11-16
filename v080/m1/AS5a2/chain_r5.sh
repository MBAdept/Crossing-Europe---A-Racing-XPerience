#!/usr/bin/env bash
# AS5a2 round 5: after the fixes (props_cities canal_b cornice, cities3d chamfer display, catalog stone bar_w):
# geometry gate, the three changed models, validate, views; then every other model whose key holds props_cities.py /
# cities3d.py again (must stay byte-identical); then chain_meas, chain_ab, chain_final (NOWAIT).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
source $S/env.sh
cd $WT
echo "start $(date +%H:%M)"
$S/geom.sh r5
$S/real.sh props/city_dutch_canal_b props/city_paris_corner props/city_belgian_stone
python3 tools/blender/validate_models.py --report > $S/logs/validate_r5.log 2>&1
echo "VALIDATE exit $?: $(grep -E 'CHECK|FEHLER' $S/logs/validate_r5.log | head -5 | tr '\n' ' ')"
I=$(python3 $S/py_items.py $WT city_dutch_canal_b,city_paris_corner,city_belgian_stone)
$S/v2.sh real_r5 "$I" close dist | grep -E "exit|fertig"
echo "PHASE2 $(date +%H:%M)"
$S/real.sh props/city_french_sud props/city_belgian_terrace props/city_french_maison props/city_french_immeuble \
	props/city_dutch_terrace props/city_paris_haussmann props/city_swiss_chalet props/city_dutch_canal props/city_swiss_laube
echo "GITSTATUS2 $(git status --short assets/models | grep -v '^??' | grep -v -E 'city_dutch_canal_b|city_paris_corner|city_belgian_stone|manifest.json' | wc -l) unerwartet geänderte Dateien"
$S/real.sh props/city_german_house props/city_german_old_fachwerk props/city_german_old_fachwerk_b \
	props/city_german_mietshaus props/city_german_gruenderzeit props/city_hanse_gabled props/city_german_old_barock \
	props/city_hanse_speicher props/city_german_office props/city_hanse_kontor props/city_hanse_crane \
	props/bridge_lamp props/bridge_pylon props/bridge_pylon_bare props/bridge_truss_arch props/houseboat
echo "GITSTATUS3 $(git status --short assets/models | grep -v '^??' | grep -v -E 'city_dutch_canal_b|city_paris_corner|city_belgian_stone|manifest.json' | wc -l) unerwartet geänderte Dateien"
git status --short assets/models | grep -v '^??' | head -20
echo "=== chain_r5 export fertig $(date +%H:%M)"
NOWAIT=1 $S/chain_meas.sh > $S/logs/chain_meas.out 2>&1
NOWAIT=1 $S/chain_ab.sh > $S/logs/chain_ab.out 2>&1
NOWAIT=1 $S/chain_final.sh > $S/logs/chain_final.out 2>&1
echo "=== chain_r5 fertig $(date +%H:%M)"
