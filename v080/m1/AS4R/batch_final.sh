#!/usr/bin/env bash
# AS4R scratch: final pictures and the first gates, strictly one heavy job after the other.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
L=$S/logs/batch_final.log
: > "$L"
echo "start $(date +%H:%M)" >> "$L"
"$S/batch_views.sh" v2
echo "views $(date +%H:%M)" >> "$L"
"$S/batch_measure.sh" m2
"$S/my.sh" m2_sparkcam --mode=sparkcam --look=race --hour=12 --preset=medium --dists=60,120,250,400 --x=20 --sprite \
	--models=props/windmill,props/building_block_b,props/bridge_truss_arch >> "$S/logs/batch_m2.log" 2>&1
echo "measure $(date +%H:%M)" >> "$L"
"$S/batch_ab.sh" f
echo "ab $(date +%H:%M)" >> "$L"
cd "$WT"
mkdir -p "$S/gates"
t0=$(date +%s)
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1 > "$S/gates/geometry.log" 2>&1
echo "geometry rc $? $(( $(date +%s) - t0 )) s $(date +%H:%M)" >> "$L"
t0=$(date +%s)
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys > "$S/gates/check_keys.log" 2>&1
echo "check_keys rc $? $(( $(date +%s) - t0 )) s $(date +%H:%M)" >> "$L"
echo FINAL_DONE >> "$L"
