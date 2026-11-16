#!/usr/bin/env bash
# QA-WASSER queue 4: terrain cover debug view (--gfx-debug=cover,far) of the EXPORTED Linux build at the
# Köhlbrandbrücke and at the Holtenau approach – holes (magenta) below the horizon, far plane (cyan), rim (yellow).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
T=$S/tools
O=$S/shots_cover
mkdir -p "$O"
cd "$S" || exit 1
KB="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --no-traffic --hour=12"
HH="--stage=kiel_hamburg --from=hamburg --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --no-traffic --hour=12"
echo "== cover kb deck $(date +%T)"
# shellcheck disable=SC2086
"$T/xshot.sh" linux "$O/kb_deck" 1280x800 modern $KB --gfx-preset=deck --start-km=77.6 --start-speed=80 --shot-times=0.3,2,4,6 --gfx-debug=cover,far
echo "== cover kb high $(date +%T)"
# shellcheck disable=SC2086
"$T/xshot.sh" linux "$O/kb_high" 1280x720 modern $KB --gfx-preset=high --start-km=77.6 --start-speed=80 --shot-times=0.3,2,4,6 --gfx-debug=cover,far
echo "== cover holtenau high $(date +%T)"
# shellcheck disable=SC2086
"$T/xshot.sh" linux "$O/hh_high" 1280x720 modern $HH --gfx-preset=high --start-km=75.5 --start-speed=120 --shot-times=0.3,1.5 --gfx-debug=cover,far
python3 -I "$T/cover_measure.py" "$O"/*_modern_[0-9][0-9].png
echo "== fertig $(date +%T)"
