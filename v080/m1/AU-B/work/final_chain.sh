#!/bin/bash
# The measurement runs with the final banks, one after the other: loudness plan (capture_mix.gd, Modern and Arcade),
# then the in-game engine captures for the A/B files.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
TAG=${1:-f1}
bash "$W/capture_all.sh" plan_$TAG modern > "$W/plan_${TAG}_modern.log" 2>&1
bash "$W/ab_all.sh" ab_$TAG > "$W/ab_$TAG.log" 2>&1
bash "$W/capture_all.sh" plan_$TAG arcade > "$W/plan_${TAG}_arcade.log" 2>&1
echo KETTE FERTIG
