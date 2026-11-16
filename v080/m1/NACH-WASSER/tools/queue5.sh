#!/usr/bin/env bash
# NACH-WASSER queue 5 (after the props unit tests): the old build 0ad9012 (Modern) at Dortmund with the same arguments
# as queue 3 – are the missing right-hand city buildings older than FIX-WASSER-R (expected: yes), and what did the old
# build show where the Florianturm stand-in stands now?
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
until grep -q "^== test_props exit" "$S/logs/after_q4.log" 2>/dev/null; do sleep 5; done
echo "== alt dortmund $(date -u +%T)"
"$S/tools/xshot.sh" linuxold "$S/shots/alt_dortmund" 1280x720 modern --stage=kassel_dortmund --from=kassel \
	--hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high --start-km=152.6 \
	--start-speed=80 --shot-times=0.3,2,4,6
echo "== fertig $(date -u +%T)"
