#!/usr/bin/env bash
# AS2R: review sheets of the heavy and police models (contact sheet with the race look): chase camera at 20 / 60 /
# 150 m by day and at night next to the Arcade box / sprite, every lamp channel at night, the levels.
# usage: heavy_review.sh <outdir> [models...]
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
O=$1
shift
mkdir -p "$O"
MODELS=${*:-traffic/truck traffic/truck_tarp traffic/truck_transport traffic/bus police/de police/be police/it police/at police/nl}
for m in $MODELS; do
	t=${m//\//_}
	echo "== $m $(date +%T)"
	"$S/bin/sheet.sh" "$O/${t}_chase.png" --only="$m" --chase=20,60,150 --arcade --tile=480x300 --cols=6 | tail -1
	"$S/bin/sheet.sh" "$O/${t}_night.png" --only="$m" --night --tile=480x320 --cols=4 | tail -1
	"$S/bin/sheet.sh" "$O/${t}_day.png" --only="$m" --tile=480x320 --cols=4 | tail -1
done
echo "== fertig $(date +%T)"
