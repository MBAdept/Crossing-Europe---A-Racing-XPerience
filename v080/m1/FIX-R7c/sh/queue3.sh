#!/bin/bash
# FIX-R7c queue 3 (after queue 2): Modern goldens of this tree and of R7c (ref) with the pictures kept, then the gates.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
until grep -q "Q2 DONE" "$S/logs/queue.out" 2>/dev/null; do sleep 20; done
echo "Q3 start $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
mkdir -p "$S/gates"
cd "$WT" || exit 1
memwait
KEEP=$S/gm_fix nice -n 10 tools/golden.sh modern-check > "$S/gates/modern_check_fix.log" 2>&1
echo "Q3 modern-check fix exit=$? $(grep 'GOLDEN modern' "$S/gates/modern_check_fix.log" | tr '\n' ' ')" >> "$S/logs/queue.out"
cd "$S/ref" || exit 1
memwait
KEEP=$S/gm_ref nice -n 10 tools/golden.sh modern-check > "$S/gates/modern_check_ref.log" 2>&1
echo "Q3 modern-check ref exit=$? $(grep 'GOLDEN modern' "$S/gates/modern_check_ref.log" | tr '\n' ' ')" >> "$S/logs/queue.out"
cd "$WT" || exit 1
memwait
XDG_DATA_HOME=$S/xdg_gate nice -n 10 godot --headless --path . --import > "$S/gates/import.log" 2>&1
echo "Q3 import exit=$?" >> "$S/logs/queue.out"
XDG_DATA_HOME=$S/xdg_gate nice -n 10 godot --headless --path . -s res://tests/check_scripts.gd > "$S/gates/check_scripts.log" 2>&1
echo "Q3 check_scripts exit=$? $(tail -1 "$S/gates/check_scripts.log")" >> "$S/logs/queue.out"
memwait
XDG_DATA_HOME=$S/xdg_gate nice -n 10 tools/run_tests.sh > "$S/gates/run_tests_1.log" 2>&1
echo "Q3 run_tests exit=$? $(grep -E 'Tests bestanden|FEHLGESCHLAGEN|fehlgeschlagen' "$S/gates/run_tests_1.log" | tail -2 | tr '\n' ' ')" >> "$S/logs/queue.out"
memwait
XDG_DATA_HOME=$S/xdg_gate nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$S/gates/modern_sight.log" 2>&1
echo "Q3 modern_sight exit=$?" >> "$S/logs/queue.out"
XDG_DATA_HOME=$S/xdg_gate nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$S/gates/modern_path.log" 2>&1
echo "Q3 modern_path exit=$?" >> "$S/logs/queue.out"
memwait
XDG_DATA_HOME=$S/xdg_rcall nice -n 10 tools/run_render_checks.sh all > "$S/gates/render_checks.log" 2>&1
echo "Q3 render_checks exit=$? $(tail -2 "$S/gates/render_checks.log" | tr '\n' ' ')" >> "$S/logs/queue.out"
echo "Q3 DONE $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
