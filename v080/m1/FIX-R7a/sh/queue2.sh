#!/bin/bash
# FIX-R7a queue 2: gates on the final head (one heavy job at a time). Steps already done are skipped (marks in done/).
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a/sh/common.sh
mkdir -p $S/done
step() { [ -f "$S/done/$1" ]; }
mark() { touch "$S/done/$1"; }
cd $WT || exit 2
if ! step import; then
	nice -n 10 godot --headless --path . --import > $S/logs/gate_import.log 2>&1; echo "import exit=$?"; mark import
	grep -ciE "error" $S/logs/gate_import.log
fi
if ! step check_scripts; then
	nice -n 10 timeout 300 godot --headless --path . -s res://tests/check_scripts.gd > $S/logs/gate_check_scripts.log 2>&1
	echo "check_scripts exit=$?"; grep -E "geprüft|KAPUTT" $S/logs/gate_check_scripts.log; mark check_scripts
fi
if ! step sight_full; then
	memwait
	nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $S/logs/gate_sight_full.log 2>&1
	echo "sight_full exit=$?"; grep -E "CHECK|SIGHT F7" $S/logs/gate_sight_full.log; mark sight_full
fi
if ! step path_full; then
	memwait
	nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $S/logs/gate_path_full.log 2>&1
	echo "path_full exit=$?"; grep -E "CHECK" $S/logs/gate_path_full.log; mark path_full
fi
if ! step base_import; then
	(cd $S/base && nice -n 10 godot --headless --path . --import > $S/logs/base_import.log 2>&1); echo "base import exit=$?"; mark base_import
fi
for pair in "kh_base:base" "kh_head:head"; do
	tag=${pair%%:*}; tree=${pair#*:}
	step "$tag" || { bash $S/sh/stage.sh "$tag" "$tree" medium kiel_hamburg kiel 12 normal 40; mark "$tag"; }
done
for pair in "sp_deck_base:base" "sp_deck_head:head"; do
	tag=${pair%%:*}; tree=${pair#*:}
	step "$tag" || { bash $S/sh/stage.sh "$tag" "$tree" deck saragossa_pau saragossa 11 normal 4 165 420; mark "$tag"; }
done
if ! step golden_check; then
	memwait
	nice -n 10 timeout 5400 tools/golden.sh check > $S/logs/gate_golden_check.log 2>&1
	echo "golden check exit=$?"; grep -E "^GOLDEN" $S/logs/gate_golden_check.log; mark golden_check
fi
if ! step golden_modern; then
	memwait
	KEEP=$S/gold_keep nice -n 10 timeout 5400 tools/golden.sh modern-check > $S/logs/gate_golden_modern.log 2>&1
	echo "golden modern-check exit=$?"; grep -E "^GOLDEN" $S/logs/gate_golden_modern.log; mark golden_modern
fi
if [ "${1:-}" = a ]; then echo QUEUE2A_DONE; exit 0; fi
if ! step run_tests; then
	memwait
	nice -n 10 timeout 3600 tools/run_tests.sh > $S/logs/gate_run_tests.log 2>&1
	echo "run_tests exit=$?"; tail -15 $S/logs/gate_run_tests.log; mark run_tests
fi
if [ "${1:-}" = b ]; then echo QUEUE2B_DONE; exit 0; fi
if ! step render_checks; then
	memwait
	nice -n 10 timeout 10800 tools/run_render_checks.sh all > $S/logs/gate_render_checks.log 2>&1
	echo "render checks exit=$?"; grep -E "RENDER-CHECK-DATEI" $S/logs/gate_render_checks.log | grep -vc " OK"; tail -5 $S/logs/gate_render_checks.log; mark render_checks
fi
echo QUEUE2_DONE
