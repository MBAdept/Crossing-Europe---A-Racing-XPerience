#!/usr/bin/env bash
# NACH-WASSER queue 3 (Linux export of the delivered build). Scenes with QA-WASSER's exact arguments (its PNGs of the
# old build 0ad9012 are the "before" pictures: m1/QA-WASSER/shots/), the night pylons at the other presets, and three
# of the four B1 cities only covered by a unit test so far.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
T=$S/tools
O=$S/shots
mkdir -p "$O"
# QA-WASSER queue1.sh: KB="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown"
QKB=(--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown)
KB=(--stage=kiel_hamburg --from=kiel --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-km=77.6 --start-speed=80 --shot-times=0.3,2,4,6)
step() { echo "== $1 $(date -u +%T)"; }
step "kb_nacht_deck 1280x800 (QA args)"
"$T/ab.sh" linux "$O/kb_nacht_deck" 1280x800 "Köhlbrandbrücke 22 Uhr, Steam Deck, 1280x800, ab km 77,6" "${QKB[@]}" --hour=22 --gfx-preset=deck \
	--start-km=77.6 --start-speed=80 --no-traffic --shot-times=0.3,2,4,6
step "kb_tag_hoch_b (QA args)"
"$T/ab.sh" linux "$O/kb_tag_hoch_b" 1280x720 "Köhlbrandbrücke 12 Uhr, Hoch, ab km 79,0" "${QKB[@]}" --hour=12 --gfx-preset=high \
	--start-km=79.0 --start-speed=80 --traffic-warmup --shot-times=0.3,2,4,6
step "kb_nacht_mittel (Modern)"
MODES=modern "$T/ab.sh" linux "$O/kb_nacht_mittel" 1280x720 "Köhlbrandbrücke 22 Uhr, Mittel" "${KB[@]}" --hour=22 --gfx-preset=medium
step "kb_nacht_niedrig (Modern)"
MODES=modern "$T/ab.sh" linux "$O/kb_nacht_niedrig" 1280x720 "Köhlbrandbrücke 22 Uhr, Niedrig" "${KB[@]}" --hour=22 --gfx-preset=low
step "dortmund (B1, Florianturm km 156)"
"$T/ab.sh" linux "$O/dortmund" 1280x720 "Kassel – Dortmund, Florianturm km 156, ab km 152,6, Hoch" --stage=kassel_dortmund --from=kassel \
	--hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high --start-km=152.6 \
	--start-speed=80 --shot-times=0.3,2,4,6
step "calais (B1, Leuchtturm km 212)"
"$T/ab.sh" linux "$O/calais" 1280x720 "Brüssel – Calais, Leuchtturm km 212, ab km 208,6, Hoch" --stage=bruessel_calais --from=bruessel \
	--hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high --start-km=208.6 \
	--start-speed=80 --shot-times=0.3,2,4,6
step "madrid (B1, Cuatro Torres km 234)"
"$T/ab.sh" linux "$O/madrid" 1280x720 "Burgos – Madrid, Cuatro Torres km 234, ab km 230,6, Hoch" --stage=burgos_madrid --from=burgos \
	--hour=12 --vehicle=limousine --seed=11 --autopilot --no-countdown --no-traffic --gfx-preset=high --start-km=230.6 \
	--start-speed=80 --shot-times=0.3,2,4,6
step "fertig"
