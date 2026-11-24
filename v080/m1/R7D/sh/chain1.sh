#!/bin/bash
# R7D chain 1 (resumable): every render check, the ones the road, sky and ground of R7d touch first
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
G=$S/gates; mkdir -p $G
cd $W
mkdir -p $S/xdg/rc; export XDG_DATA_HOME=$S/xdg/rc
first="tests/race3d/render/check_freie_strecke.gd tests/race3d/render/check_road_parity.gd tests/race3d/render/check_weather.gd tests/race3d/render/check_night_nass.gd tests/race3d/render/check_night.gd tests/race3d/render/check_weather_tabelle.gd tests/race3d/render/check_weather_tabelle_schnee.gd tests/race3d/render/check_modern_render.gd tests/race3d/render/check_terrain_cover.gd tests/race3d/render/check_seam_render.gd"
for f in $first tests/race/check_glow_occlusion.gd tests/race/check_sprite_flip.gd $(find tests/race3d/render -maxdepth 1 -name 'check_*.gd' | sort); do
	b=$(basename $f)
	grep -qE "RENDER-CHECK-DATEI $f " $G/render_checks.log 2>/dev/null && continue
	what=modern; case "$f" in tests/race/*) what=arcade ;; esac
	nice -n 10 tools/run_render_checks.sh $what $b 2>&1 | grep -vE "^==>" >> $G/render_checks.log
	[ "$f" = tests/race3d/render/check_seam_render.gd ] && echo "$(date +%T) RISKY DONE" >> $G/summary.txt
done
echo "$(date +%T) render checks – $(grep -cE 'RENDER-CHECK-DATEI .* OK' $G/render_checks.log) Dateien OK, $(grep -cE 'RENDER-CHECK-DATEI .* (FEHLER|ZEITLIMIT)' $G/render_checks.log) Dateien rot" >> $G/summary.txt
echo "CHAIN1 DONE $(date +%T)" >> $G/summary.txt
