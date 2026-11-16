#!/usr/bin/env bash
# KRITIK-4 batch 4: follow-ups (factory roof triangles at night from all sides, ferry outline with the right yaw,
# windmill sails in motion). Waits for batch 3. Progress in $K/logs/batch4.log
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4
L=$K/logs/batch4.log
: > "$L"
until grep -q BATCH3_DONE $K/logs/batch3.log 2>/dev/null; do sleep 10; done
$K/ks.sh fabrik_dreh_nacht --mode=turn --look=race --hour=23 --preset=high --dist=70 --x=0 --yaws=0,30,60,90,180,270,315,330 --lod=lod0 --models=props/factory >> "$L" 2>&1
$K/ks.sh fabrik_dreh_tag --mode=turn --look=race --hour=12 --preset=high --dist=70 --x=0 --yaws=0,30,330 --lod=lod0 --models=props/factory >> "$L" 2>&1
$K/k4.sh umriss_c2 --mode=outline2 --ppm=5 --lods=lod0 "--items=props/ferry_ship" >> "$L" 2>&1
echo BATCH4_DONE >> "$L"
