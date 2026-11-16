#!/usr/bin/env bash
# AS5aR1: sprite geometry gate, then the real exports of all eleven city models and the bridge parts whose key
# holds props_cities.py (must come out byte-identical), then the stale check. Detached (setsid) - runs > 2 h.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
source $S/env.sh
until grep -q "=== r2 fertig" $S/logs/r2.out 2>/dev/null; do sleep 20; done
echo "start $(date +%H:%M)"
cd $WT
waitmem
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1 > $S/logs/gate_geom.log 2>&1
echo "GEOM exit $? $(date +%H:%M): $(grep -E 'Sprite-Sets gebaut|CHECK|ANDERS' $S/logs/gate_geom.log | tr '\n' ' ')"
$S/real.sh props/city_german_house props/city_german_old_fachwerk props/city_german_old_fachwerk_b \
	props/city_german_mietshaus props/city_german_gruenderzeit props/city_hanse_gabled props/city_german_old_barock \
	props/city_hanse_speicher props/city_german_office props/city_hanse_kontor props/city_hanse_crane
$S/real.sh props/bridge_pylon props/bridge_pylon_bare props/bridge_truss_arch
cd $WT
nice -n 19 /home/user/tools/bpyenv/bin/python $S/tools/stale.py $WT 2>&1 | grep -E "VERALTET|veraltet"
git status --porcelain -- assets/models | grep -v 'props/city_' | head -20
echo "=== chain_final fertig $(date +%H:%M)"
