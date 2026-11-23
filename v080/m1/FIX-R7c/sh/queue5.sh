#!/bin/bash
# FIX-R7c queue 5: after the view-clock fix (b22b90b) – check_weather on this tree and on R7c (ref, A-11 comparison),
# check_weather_tabelle_schnee (not reached), check_lod_band, check_start_km0 and check_session_modern again (props.gd
# changed), then modern-make with the pictures kept and the countdown picture at "Hoch".
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
while pgrep -f "check_weather_tabelle.gd" > /dev/null; do sleep 10; done
echo "Q5 start $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
cd "$WT" || exit 1
for f in check_weather.gd check_weather_tabelle_schnee.gd check_lod_band.gd check_start_km0.gd check_session_modern.gd; do
	memwait
	XDG_DATA_HOME=$S/xdg_rcall nice -n 10 tools/run_render_checks.sh modern "$f" >> "$S/gates/render_checks_3.log" 2>&1
	echo "Q5 $f exit=$?" >> "$S/logs/queue.out"
done
cd "$S/ref" || exit 1
memwait
XDG_DATA_HOME=$S/xdg_rcref nice -n 10 tools/run_render_checks.sh modern check_weather.gd > "$S/gates/render_checks_ref_weather.log" 2>&1
echo "Q5 ref check_weather exit=$?" >> "$S/logs/queue.out"
cd "$WT" || exit 1
memwait
KEEP=$S/gm_make nice -n 10 tools/golden.sh modern-make > "$S/gates/modern_make.log" 2>&1
echo "Q5 modern-make exit=$? $(grep -E 'Hashes' "$S/gates/modern_make.log")" >> "$S/logs/queue.out"
"$S/sh/pics.sh" start_high
echo "Q5 DONE $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
