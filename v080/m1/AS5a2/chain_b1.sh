#!/usr/bin/env bash
# AS5a2: after chain_real - the models whose cache key holds props_cities.py / cities3d.py (batch 1 of AS5a, the
# bridge parts and the houseboat) exported again; they must come out byte-identical (git status of their folders).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
source $S/env.sh
until grep -q "=== chain_real fertig" $S/logs/chain_real.out 2>/dev/null; do sleep 30; done
echo "start $(date +%H:%M)"
cd $WT
$S/real.sh props/city_german_house props/city_german_old_fachwerk props/city_german_old_fachwerk_b \
	props/city_german_mietshaus props/city_german_gruenderzeit props/city_hanse_gabled props/city_german_old_barock \
	props/city_hanse_speicher props/city_german_office props/city_hanse_kontor props/city_hanse_crane \
	props/bridge_lamp props/bridge_pylon props/bridge_pylon_bare props/bridge_truss_arch props/houseboat
echo "GITSTATUS $(git status --short assets/models/props/city_german_* assets/models/props/city_hanse_* assets/models/props/bridge_* assets/models/props/houseboat | wc -l) geänderte Dateien"
git status --short assets/models/props/city_german_* assets/models/props/city_hanse_* assets/models/props/bridge_* assets/models/props/houseboat | head -20
echo "=== chain_b1 fertig $(date +%H:%M)"
