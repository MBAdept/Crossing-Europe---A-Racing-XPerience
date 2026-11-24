#!/bin/bash
# R7D chain 4 (resumable) on the head after the lawn fix (e8c6f07): the full test suite again, then every render check again
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
G=$S/gates; mkdir -p $G
cd $W
echo "$(date +%T) chain4 auf $(git rev-parse --short HEAD)" >> $G/summary.txt
if ! grep -q "Tests, " $G/run_tests_2.log 2>/dev/null; then
	rm -rf $S/xdg/rt2; mkdir -p $S/xdg/rt2; XDG_DATA_HOME=$S/xdg/rt2 nice -n 10 tools/run_tests.sh > $G/run_tests_2.log 2>&1
	echo "$(date +%T) run_tests (2) exit $? – $(grep -E 'Tests, ' $G/run_tests_2.log | tail -1) – $(grep -cE '^CHECK .* OK' $G/run_tests_2.log) CHECK OK, $(grep -cE '^CHECK .* FEHLER' $G/run_tests_2.log) CHECK FEHLER" >> $G/summary.txt
fi
mkdir -p $S/xdg/rc2; export XDG_DATA_HOME=$S/xdg/rc2
first="tests/race3d/render/check_structures_licht.gd tests/race3d/render/check_freie_strecke.gd tests/race3d/render/check_weather_tabelle.gd tests/race3d/render/check_modern_render.gd tests/race3d/render/check_terrain_cover.gd"
for f in $first tests/race/check_glow_occlusion.gd tests/race/check_sprite_flip.gd $(find tests/race3d/render -maxdepth 1 -name 'check_*.gd' | sort); do
	grep -qE "RENDER-CHECK-DATEI $f " $G/render_checks_2.log 2>/dev/null && continue
	what=modern; case "$f" in tests/race/*) what=arcade ;; esac
	nice -n 10 tools/run_render_checks.sh $what $(basename $f) 2>&1 | grep -vE "^==>" >> $G/render_checks_2.log
done
echo "$(date +%T) render checks (2) – $(grep -cE 'RENDER-CHECK-DATEI .* OK' $G/render_checks_2.log) Dateien OK, $(grep -cE 'RENDER-CHECK-DATEI .* (FEHLER|ZEITLIMIT)' $G/render_checks_2.log) Dateien rot" >> $G/summary.txt
echo "CHAIN4 DONE $(date +%T)" >> $G/summary.txt
