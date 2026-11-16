#!/usr/bin/env bash
# AS5aR1: house lod1 garden ratio test (0.5 against the committed 0.3): export, lods at 12 and 22 h
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
source $S/env.sh
until grep -q "=== meas_final fertig" $S/logs/meas_final.out 2>/dev/null; do sleep 20; done
cd $WT
sed -i 's/lod1_decimate={"gh_hedge": 0.3, "gh_tree_c": 0.3}/lod1_decimate={"gh_hedge": 0.5, "gh_tree_c": 0.5}/' tools/blender/ce3d/catalog3d.py
grep -n 'lod1_decimate' tools/blender/ce3d/catalog3d.py
$S/real.sh props/city_german_house | grep -E "EXPORT|DONE"
python3 tools/blender/validate_models.py 2>&1 | grep -E "CHECK|FEHLER" | head -3
for h in 12 22; do
	$S/k5.sh k5_scene house05/lods_h$h --mode=lods "--models=props/city_german_house" --sprite --x=20 --look=race --hour=$h --preset=medium | grep UMSCHALT
done
echo "=== house_test fertig $(date +%H:%M)"
