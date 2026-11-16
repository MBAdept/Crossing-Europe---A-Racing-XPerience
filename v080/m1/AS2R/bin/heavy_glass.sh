#!/usr/bin/env bash
# AS2R: after heavy_probe.sh: rebuild trucks and buses (far glass), probe the bus / truck at 60 m again, re-render the
# bus chase sheet for the delivery.  -> logs/heavy_glass.log (GLASSDONE)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
K=$S/kritik
until grep -q HEAVYDONE "$S/logs/heavy_probe.log" 2>/dev/null; do sleep 5; done
echo "== $(date +%T) rebuild traffic/truck* traffic/bus"
"$S/bin/rebuild.sh" "traffic/truck*" --novalidate
"$S/bin/rebuild.sh" "traffic/bus"
echo "== $(date +%T) hs60g"
nice -n 19 "$K/probe.sh" hs60g 60 lod0 lod1 traffic/bus_white traffic/truck_red 2>&1 | grep -E "m lod|jobs in"
python3 "$K/bin/buswin.py" "$K/out/hs60g" bus_white 60 lod0 lod1
echo "== $(date +%T) hs180g"
nice -n 19 "$K/probe.sh" hs180g 180 lod1 lod2 traffic/bus_white 2>&1 | grep -E "m lod|jobs in"
echo "== $(date +%T) chase"
"$S/bin/sheet.sh" "$S/out/deliver/h_traffic_bus_chase.png" --only="traffic/bus" --chase=20,60,150 --arcade --tile=480x300 --cols=6 | tail -1
echo "== $(date +%T) GLASSDONE"
