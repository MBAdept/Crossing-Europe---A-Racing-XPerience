#!/usr/bin/env bash
# Times every part of tools/run_tests.sh separately (baseline for "both modes without doubling the time").
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)"
cd "$S/proj"
export XDG_DATA_HOME="$S/xdg"
LOG="$S/logs/time_tests.log"
: > "$LOG"
t() { # name, command...
	local name="$1"; shift
	local t0=$(date +%s.%N)
	"$@" > "$S/logs/part_$name.log" 2>&1
	local code=$?
	local t1=$(date +%s.%N)
	printf "%-22s %7.1f s  exit %d  load %s\n" "$name" "$(echo "$t1 - $t0" | bc)" "$code" "$(cut -d' ' -f1 /proc/loadavg)" | tee -a "$LOG"
}
t import godot --headless --path . --import
t check_scripts timeout 300 godot --headless --path . -s res://tests/check_scripts.gd
t unit_tests timeout 900 godot --headless --path . -s res://tests/run_tests.gd
t check_session timeout 300 godot --headless --path . -s res://tests/race/check_session.gd
t check_attract timeout 300 godot --headless --path . -s res://tests/race/check_attract.gd
t check_menu_pad timeout 300 godot --headless --path . -s res://tests/race/check_menu_pad.gd
t check_attract_scenes timeout 600 godot --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd
t check_escapes timeout 600 godot --headless --path . -s res://tests/sim/check_escapes.gd
echo DONE | tee -a "$LOG"
