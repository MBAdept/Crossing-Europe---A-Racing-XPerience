#!/usr/bin/env bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
COMMON="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 --shot-times=1"
export GFX_ARGS="--gfx-preset=high"
$S/sh/ab.sh $S/shots/q_hh22 --stage=kiel_hamburg --from=kiel --start-km=85.6 --hour=22 $COMMON
$S/sh/ab.sh $S/shots/q_parsky --stage=luettich_paris --from=luettich --start-km=376 --hour=12 $COMMON
