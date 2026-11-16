#!/usr/bin/env bash
# AS5aR1: after chain_final - the other models whose key holds props_cities.py (must stay byte-identical), the
# determinism check (second forced export of two city models), then the measurements on the real exports.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
source $S/env.sh
until grep -q "=== chain_final fertig" $S/logs/chain_final.out 2>/dev/null; do sleep 30; done
echo "start $(date +%H:%M)"
$S/real.sh props/bridge_lamp props/houseboat
cd $WT
git status --porcelain -- assets/models | grep -v 'props/city_' | head -20
$S/tools/det.sh props/city_german_office,props/city_hanse_crane
$S/meas_final.sh validate lods spark outline tint dist close erker drive rail
echo "=== post1 fertig $(date +%H:%M)"
