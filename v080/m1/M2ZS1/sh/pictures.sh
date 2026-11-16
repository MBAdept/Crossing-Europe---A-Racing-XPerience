#!/usr/bin/env bash
# M2ZS1: the A/B series of the merged tree (sequential, nice 10 via ab.sh). Log: logs/pictures.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2ZS1
AB=$S/sh/ab.sh
START="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1,4.5"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80 --start-km=77.6"
O60="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --start-speed=60 --no-traffic --hour=12"
O80="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --no-traffic --hour=12 --start-speed=80"
echo "== start $(date -u +%T)"
GFX_ARGS="--gfx-preset=medium" $AB start_mittel $START
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" $AB start_deck $START
GFX_ARGS="--gfx-preset=high" $AB kb_nacht_high $KH --hour=22 --shot-times=0.3,2,4,4.3,6
GFX_ARGS="--gfx-preset=high" $AB kb_tag_high $KH --hour=12 --shot-times=0.3,2,4,4.3,6
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" $AB kb_nacht_deck $KH --hour=22 --shot-times=0.3,2,4,4.3
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" $AB kb_tag_deck $KH --hour=12 --shot-times=0.3,2,4,4.3
GFX_ARGS="--gfx-preset=high" $AB holtenau --stage=rostock_kiel --from=rostock $O60 --start-km=200.0 --shot-times=0.3,1.5,2.5,4
GFX_ARGS="--gfx-preset=high" $AB belgrad --stage=slavonski_brod_belgrad --from=slavonski_brod $O80 --start-km=198.6 --shot-times=0.3,2,4,5,6
echo "== fertig $(date -u +%T)"
