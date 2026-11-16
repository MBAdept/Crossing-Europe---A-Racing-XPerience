#!/usr/bin/env bash
# NACH-WASSER queue 4: side effect of the far-landmark tint (props.gd _update_far_landmarks reads "tint" for every far
# landmark now). Kiel – Hamburg from Hamburg: the tinted "Rathausturm" (props/church, tint #c4927a) at km 92.8 – new
# build (Arcade + Modern) and old build 0ad9012 (Modern), same arguments.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
T=$S/tools
O=$S/shots
ARGS=(--stage=kiel_hamburg --from=hamburg --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never \
	--no-countdown --no-traffic --hour=12 --gfx-preset=high --start-km=90.6 --start-speed=80 --shot-times=0.3,2,4,6)
step() { echo "== $1 $(date -u +%T)"; }
step "kiel_ankunft new (Arcade + Modern)"
"$T/ab.sh" linux "$O/kiel_ankunft" 1280x720 "Hamburg – Kiel, Rathausturm km 92,8 (getönt), ab km 90,6, Hoch" "${ARGS[@]}"
step "kiel_ankunft old (Modern, 0ad9012)"
"$T/xshot.sh" linuxold "$O/alt_kiel_ankunft" 1280x720 modern "${ARGS[@]}"
step "fertig"
