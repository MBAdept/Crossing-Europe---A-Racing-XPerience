#!/usr/bin/env bash
# AS5aR2: real exports of all 23 city models (code frozen), then the five other models whose key holds
# props_cities.py (must come out byte-identical), manifest, validator.  Progress: grep -E "EXPORT|STAGE" logs/chain_real.out
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
B2="props/city_french_sud props/city_belgian_terrace props/city_french_maison props/city_french_immeuble props/city_dutch_terrace props/city_belgian_stone props/city_paris_haussmann props/city_swiss_chalet props/city_dutch_canal props/city_swiss_laube props/city_dutch_canal_b props/city_paris_corner"
B1="props/city_german_gruenderzeit props/city_german_mietshaus props/city_german_house props/city_hanse_kontor props/city_hanse_gabled props/city_hanse_speicher props/city_german_old_fachwerk props/city_german_old_fachwerk_b props/city_german_old_barock props/city_german_office props/city_hanse_crane"
OTHER="props/bridge_lamp props/bridge_pylon props/bridge_pylon_bare props/bridge_truss_arch props/houseboat"
echo "STAGE batch2 $(date +%H:%M)"
$S/real.sh $B2
echo "STAGE batch1 $(date +%H:%M)"
$S/real.sh $B1
echo "STAGE other $(date +%H:%M)"
$S/real.sh $OTHER
echo "GITSTATUS_OTHER $(git status --short -- assets/models/props/bridge_* assets/models/props/houseboat | wc -l)"
nice -n 19 python3 tools/blender/validate_models.py --report > $S/logs/validate_real.log 2>&1
echo "VALIDATE $(tail -1 $S/logs/validate_real.log)"
echo "STAGE fertig $(date +%H:%M)"
