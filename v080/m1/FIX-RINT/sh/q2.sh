#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
while pgrep -f "sh/q1.sh" > /dev/null; do sleep 5; done
echo "q2: TS15N v2 start $(date +%T)"
GFX_ARGS=--gfx-preset=high $S/sh/mshot.sh $S/shots/ts15n_v2/TS15N --stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-km=14.3 --hour=21 --weather=normal --start-speed=100 --shot-times=1.5,2.5
echo "q2: done $(date +%T)"
