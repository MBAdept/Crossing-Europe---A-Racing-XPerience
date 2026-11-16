#!/usr/bin/env bash
# NACH-WASSER queue 6 (after queue 5): Dortmund, the last ~1.5 km before the Florianturm stand-in (km 156) – does it
# stay in view up to its chunk and beyond (no pop-out at the hand-over far -> chunk)? New build, Arcade + Modern.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
until grep -q "^== fertig" "$S/logs/queue5.log" 2>/dev/null; do sleep 5; done
echo "== dortmund_nah $(date -u +%T)"
"$S/tools/ab.sh" linux "$S/shots/dortmund_nah" 1280x720 "Kassel – Dortmund, Florianturm km 156, ab km 154,4, Hoch" \
	--stage=kassel_dortmund --from=kassel --hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic \
	--gfx-preset=high --start-km=154.4 --start-speed=80 --shot-times=0.3,1,1.7,2.4,3.1
echo "== fertig $(date -u +%T)"
