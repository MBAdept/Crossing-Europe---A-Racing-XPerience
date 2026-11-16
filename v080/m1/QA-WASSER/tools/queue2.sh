#!/usr/bin/env bash
# QA-WASSER queue 2: the Windows export under wine64 (own WINEPREFIX, TMPDIR unset, Z:<abs path>):
# Köhlbrandbrücke (same arguments as the Linux run kb_tag_hoch_b, first two shot times) and the start at km 0
# (same arguments as the Linux run start_km0).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
T=$S/tools
O=$S/shots_win
mkdir -p "$O"
cd "$S" || exit 1
unset TMPDIR
KB="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown"
echo "== wineboot $(date +%H:%M:%S)"
export WINEPREFIX=$S/wine/prefix WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
mkdir -p "$S/wine"
timeout 600 xvfb-run -a wineboot -u >"$S/wine/wineboot.log" 2>&1
echo "wineboot exit $?"
wineserver -w
echo "== wine_kb $(date +%H:%M:%S)"
# shellcheck disable=SC2086
"$T/ab.sh" windows "$O/wine_kb" 1280x720 "Köhlbrandbrücke Tag, Hoch, ab km 79,0 (Windows-Export unter Wine)" $KB --hour=12 --gfx-preset=high --start-km=79.0 --start-speed=80 --traffic-warmup --shot-times=0.3,2
echo "== wine_start $(date +%H:%M:%S)"
"$T/ab.sh" windows "$O/wine_start" 1280x720 "Kiel–Hamburg Start km 0, Mittel (Windows-Export unter Wine)" --stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-traffic --gfx-preset=medium --shot-times=1,4.5
echo "== fertig $(date +%H:%M:%S)"
