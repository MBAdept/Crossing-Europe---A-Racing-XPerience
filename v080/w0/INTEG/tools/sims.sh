#!/usr/bin/env bash
# Integration helper (not part of the repository): the network-wide Modern checks, one after the other.
# Usage: sims.sh <project dir> <log dir> <xdg dir>
set -uo pipefail
PROJ=$1
LOGS=$2
export XDG_DATA_HOME=$3
mkdir -p "$LOGS" "$XDG_DATA_HOME"
cd "$PROJ"
run() { # <log name> <script> [args after --]
	local name=$1 script=$2
	shift 2
	local t0=$SECONDS
	if [ $# -gt 0 ]; then
		nice -n 10 timeout 1500 godot --headless --path . -s "res://$script" -- "$@" > "$LOGS/$name.log" 2>&1
	else
		nice -n 10 timeout 1500 godot --headless --path . -s "res://$script" > "$LOGS/$name.log" 2>&1
	fi
	local code=$?
	echo "== $name: Exit $code, $((SECONDS - t0)) s, FEHLER-Zeilen $(grep -c '^CHECK.*FEHLER' "$LOGS/$name.log"), Skriptfehler $(grep -c 'SCRIPT ERROR' "$LOGS/$name.log")"
	grep -E '^CHECK' "$LOGS/$name.log"
}
run sight_full tests/sim/modern_sight.gd --full
run path_normal tests/sim/modern_path_check.gd
run path_full tests/sim/modern_path_check.gd --full
run sight_normal tests/sim/modern_sight.gd
