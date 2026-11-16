#!/usr/bin/env bash
# M2ZS1: after the series – night "Hoch" again with PYLON_NIGHT_ALBEDO 0.45, then the beacon probe (two shots 0.8 s
# apart, about 1 km before the first pylon pair, no traffic). Log: logs/after.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2ZS1
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80 --start-km=77.6"
echo "== start $(date -u +%T)"
GFX_ARGS="--gfx-preset=high" "$S/sh/ab.sh" kb_nacht_high $KH --hour=22 --shot-times=0.3,2,4,4.3,6
GFX_ARGS="--gfx-preset=high" "$S/sh/ab.sh" beacon --stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --no-traffic --start-speed=60 --hour=22 --start-km=76.9 --shot-times=1,1.8
echo "== fertig $(date -u +%T)"
