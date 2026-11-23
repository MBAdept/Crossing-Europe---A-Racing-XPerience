#!/bin/bash
# FIX-R7c queue 4: the render check files queue 3 did not reach (its time limit stopped it after 16 of 29, all OK),
# one call per file; then modern-make (pictures kept) and the countdown picture at "Hoch" (1280x720).
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
echo "Q4 start $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
cd "$WT" || exit 1
for f in check_seam_render.gd check_session_modern.gd check_showroom_render.gd check_start_km0.gd check_structures.gd \
	check_structures_licht.gd check_terrain_cover.gd check_tunnel_bridge.gd check_vehicle_lights.gd check_vehicle_standin.gd \
	check_weather.gd check_weather_tabelle.gd check_weather_tabelle_schnee.gd; do
	if grep -q "RENDER-CHECK-DATEI tests/race3d/render/$f " "$S/gates/render_checks_2.log" 2>/dev/null; then
		continue
	fi
	memwait
	XDG_DATA_HOME=$S/xdg_rcall nice -n 10 tools/run_render_checks.sh modern "$f" >> "$S/gates/render_checks_2.log" 2>&1
	echo "Q4 $f exit=$?" >> "$S/logs/queue.out"
done
echo "Q4 render checks done $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
memwait
KEEP=$S/gm_make nice -n 10 tools/golden.sh modern-make > "$S/gates/modern_make.log" 2>&1
echo "Q4 modern-make exit=$? $(grep -E 'Hashes' "$S/gates/modern_make.log")" >> "$S/logs/queue.out"
"$S/sh/pics.sh" start_high
echo "Q4 DONE $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
