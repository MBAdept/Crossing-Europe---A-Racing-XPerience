#!/usr/bin/env bash
# AS4R scratch: the rest of batch_final.sh (stopped by the time limit during the A/B runs), strictly one heavy
# job after the other: remaining A/B pictures, truss flicker after the darker steel, geometry gate, check-keys.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
L=$S/logs/batch_rest.log
A=$S/logs/batch_ab_f2.log
: > "$L"
: > "$A"
echo "start $(date +%H:%M)" >> "$L"
"$S/ab.sh" f_dorf_mittag high --stage=paris_tours --from=paris --start-km=129.0 --hour=12 --start-speed=100 --shot-times=1,6,9 >> "$A" 2>&1
"$S/ab.sh" f_fabrik_nacht high --stage=bremen_dortmund --from=dortmund --start-km=1.9 --hour=23 --start-speed=100 --shot-times=1,3 >> "$A" 2>&1
"$S/ab.sh" f_turm_nachmittag high --stage=dresden_leipzig --from=dresden --start-km=111.0 --hour=15 --start-speed=100 --shot-times=2,5 >> "$A" 2>&1
"$S/ab.sh" f_elbe_deck deck --stage=kiel_hamburg --from=kiel --start-km=82.9 --start-speed=50 --shot-times=1,5 --hour=19.5 >> "$A" 2>&1
echo "ab $(date +%H:%M)" >> "$L"
"$S/k4.sh" m3_flimmer_portal --mode=sparkle --look=race --hour=12 --preset=medium --dists=50,100,250,400 --x=0 --sprite --models=props/bridge_truss_arch >> "$L" 2>&1
echo "portal $(date +%H:%M)" >> "$L"
cd "$WT"
mkdir -p "$S/gates"
t0=$(date +%s)
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1 > "$S/gates/geometry.log" 2>&1
echo "geometry rc $? $(( $(date +%s) - t0 )) s $(date +%H:%M)" >> "$L"
t0=$(date +%s)
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys > "$S/gates/check_keys.log" 2>&1
echo "check_keys rc $? $(( $(date +%s) - t0 )) s $(date +%H:%M)" >> "$L"
echo REST_DONE >> "$L"
