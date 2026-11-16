#!/usr/bin/env bash
# AS2R: LOD-swap probes of truck and bus at their own switch distances (60 m lod0->lod1, 180 m lod1->lod2),
# plus chase sheets of the heavy / police models in their final state for the delivery.  -> logs/heavy_probe.log
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
K=$S/kritik
echo "== $(date +%T) hs60"
nice -n 19 "$K/probe.sh" hs60 60 lod0 lod1 traffic/truck_red traffic/bus_white 2>&1 | grep -v "^$"
echo "== $(date +%T) hs180"
nice -n 19 "$K/probe.sh" hs180 180 lod1 lod2 traffic/truck_red traffic/bus_white 2>&1 | grep -v "^$"
echo "== $(date +%T) chase sheets"
for m in police/de police/be traffic/bus traffic/truck_tarp; do
	t=${m//\//_}
	"$S/bin/sheet.sh" "$S/out/deliver/h_${t}_chase.png" --only="$m" --chase=20,60,150 --arcade --tile=480x300 --cols=6 | tail -1
done
echo "== $(date +%T) HEAVYDONE"
