#!/bin/bash
# R7D final round (resumable) on 6092197, slot A: the full test suite, then every render check
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
G=$S/gates; cd $W
echo "$(date +%T) slot3a auf $(git rev-parse --short HEAD)" >> $G/summary.txt
if ! grep -q "Tests, " $G/run_tests_3.log 2>/dev/null; then
	rm -rf $S/xdg/rt3; mkdir -p $S/xdg/rt3; XDG_DATA_HOME=$S/xdg/rt3 nice -n 10 tools/run_tests.sh > $G/run_tests_3.log 2>&1
	echo "$(date +%T) run_tests (3) exit $? – $(grep -E 'Tests, ' $G/run_tests_3.log | tail -1) – $(grep -cE '^CHECK .* OK' $G/run_tests_3.log) CHECK OK, $(grep -cE '^CHECK .* FEHLER' $G/run_tests_3.log) CHECK FEHLER" >> $G/summary.txt
fi
mkdir -p $S/xdg/rc3; export XDG_DATA_HOME=$S/xdg/rc3
first="tests/race3d/render/check_freie_strecke.gd tests/race3d/render/check_structures_licht.gd tests/race3d/render/check_weather_tabelle.gd tests/race3d/render/check_weather_tabelle_schnee.gd tests/race3d/render/check_modern_render.gd tests/race3d/render/check_terrain_cover.gd tests/race3d/render/check_weather.gd"
for f in $first tests/race/check_glow_occlusion.gd tests/race/check_sprite_flip.gd $(find tests/race3d/render -maxdepth 1 -name 'check_*.gd' | sort); do
	grep -qE "RENDER-CHECK-DATEI $f " $G/render_checks_3.log 2>/dev/null && continue
	what=modern; case "$f" in tests/race/*) what=arcade ;; esac
	nice -n 10 tools/run_render_checks.sh $what $(basename $f) 2>&1 | grep -vE "^==>" >> $G/render_checks_3.log
done
echo "$(date +%T) render checks (3) – $(grep -cE 'RENDER-CHECK-DATEI .* OK' $G/render_checks_3.log) Dateien OK, $(grep -cE 'RENDER-CHECK-DATEI .* (FEHLER|ZEITLIMIT)' $G/render_checks_3.log) Dateien rot" >> $G/summary.txt
echo "SLOT3A DONE $(date +%T)" >> $G/summary.txt
