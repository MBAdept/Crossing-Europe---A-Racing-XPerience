#!/usr/bin/env bash
# NACH-WASSER queue 2: Windows export under Wine (own WINEPREFIX, TMPDIR unset) – Köhlbrandbrücke night "Hoch" and
# the standing start at km 0, Arcade and Modern, same arguments as queue 1 (Linux) for a pixel comparison.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
T=$S/tools
O=$S/shots_win
mkdir -p "$O"
unset TMPDIR
KB=(--stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-km=77.6 --start-speed=80 --shot-times=0.3,2,4,6)
step() { echo "== $1 $(date -u +%T)"; }
step "windows kb_nacht_hoch"
"$T/ab.sh" windows "$O/kb_nacht_hoch" 1280x720 "Köhlbrandbrücke 22 Uhr, Hoch, ab km 77,6" "${KB[@]}" --hour=22 --gfx-preset=high
step "windows start_km0"
"$T/ab.sh" windows "$O/start_km0" 1280x720 "Kiel – Hamburg, stehender Start, Mittel" --stage=kiel_hamburg --from=kiel --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-traffic --hour=12 --gfx-preset=medium --shot-times=1,4.5
step "fertig"
