#!/usr/bin/env bash
# AS2R: contact sheets for the delivery (race look), one after the other.  usage: deliver_sheets.sh <outdir>
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
O=$1
mkdir -p "$O"
CARS="traffic/suv,traffic/van,traffic/sports,traffic/sedan,traffic/hatch,traffic/wagon"
echo "== $(date +%T)"
"$S/bin/sheet.sh" "$O/k_tag_spieler.png" --only="player/*" --tile=480x320 --cols=4 | tail -1
"$S/bin/sheet.sh" "$O/k_nacht_spieler.png" --only="player/*" --night --tile=400x260 --cols=6 | tail -1
"$S/bin/sheet.sh" "$O/k_tag_verkehr.png" --only="$CARS" --tile=400x260 --cols=6 | tail -1
"$S/bin/sheet.sh" "$O/k_nacht_verkehr.png" --only="traffic/suv,traffic/van,traffic/sports" --night --tile=400x260 --cols=6 | tail -1
"$S/bin/sheet.sh" "$O/k_tag_polizei.png" --only="police/*" --lods=lod0 --tile=320x210 --cols=6 | tail -1
"$S/bin/sheet.sh" "$O/k_showroom_ab.png" --only="player/*" --showroom --tonemap=agx --cols=2 | tail -1
"$S/bin/sheet.sh" "$O/k_lampenkanaele.png" --channels --tile=640x200 --cols=2 | tail -1
echo "== fertig $(date +%T)"
