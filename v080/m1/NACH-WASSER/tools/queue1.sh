#!/usr/bin/env bash
# NACH-WASSER queue 1 (Linux export of the delivered build): B2 night pylons, start km 0, B1 Belgrade + Hannover.
# One Godot run at a time. Log: m1/NACH-WASSER/logs/queue1.log
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
T=$S/tools
O=$S/shots
mkdir -p "$O"
KB=(--stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-km=77.6 --start-speed=80 --shot-times=0.3,2,4,6)
step() { echo "== $1 $(date -u +%T)"; }
step "kb_nacht_hoch (B2, QA repro)"
"$T/ab.sh" linux "$O/kb_nacht_hoch" 1280x720 "Köhlbrandbrücke 22 Uhr, Hoch, ab km 77,6" "${KB[@]}" --hour=22 --gfx-preset=high
step "start_km0 (Mittel)"
"$T/ab.sh" linux "$O/start_km0" 1280x720 "Kiel – Hamburg, stehender Start, Mittel" --stage=kiel_hamburg --from=kiel --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-traffic --hour=12 --gfx-preset=medium --shot-times=1,4.5
step "belgrad (B1, QA repro)"
"$T/ab.sh" linux "$O/belgrad" 1280x720 "Slavonski Brod – Belgrad, Ada-Brücke, ab km 198,6, Hoch" --stage=slavonski_brod_belgrad \
	--from=slavonski_brod --hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high \
	--start-km=198.6 --start-speed=80 --shot-times=0.3,2,4
step "hannover (B1)"
"$T/ab.sh" linux "$O/hannover" 1280x720 "Hamburg – Hannover, Neues Rathaus km 148,5, ab km 147,0, Hoch" --stage=hamburg_hannover \
	--from=hamburg --hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high \
	--start-km=147.0 --start-speed=80 --shot-times=0.3,2,4
step "fertig"
