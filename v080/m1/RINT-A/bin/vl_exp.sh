#!/bin/bash
# Brake light check under three quality sets: vl_exp.sh <tag>  (default = recommended preset for llvmpipe = low)
B=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A
tag=$1
echo "== $tag default (low)"
bash $B/xs.sh vl_${tag}_low res://tests/race3d/render/check_vehicle_lights.gd --only=bremslicht --save=$S/vl/${tag}_low | grep "RENDER-CHECK bremslicht"
echo "== $tag scale=100"
bash $B/xs.sh vl_${tag}_s100 res://tests/race3d/render/check_vehicle_lights.gd --only=bremslicht --gfx=scale=100 --save=$S/vl/${tag}_s100 | grep "RENDER-CHECK bremslicht"
echo "== $tag preset high"
bash $B/xs.sh vl_${tag}_high res://tests/race3d/render/check_vehicle_lights.gd --only=bremslicht --gfx-preset=high --save=$S/vl/${tag}_high | grep "RENDER-CHECK bremslicht"
