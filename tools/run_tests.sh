#!/usr/bin/env bash
# Runs all headless unit tests. Usage: tools/run_tests.sh [filter]
# Fails if a test fails OR Godot reports a script/parse error.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
LOG=$(mktemp)
timeout 300 "$GODOT" --headless --path . -s res://tests/check_scripts.gd >"$LOG" 2>&1
grep -E "KAPUTT|geprüft|SCRIPT ERROR|Parse Error|at: GDScript" "$LOG" | head -60
if grep -qE "KAPUTT" "$LOG"; then
	echo "==> Skripte mit Parse-Fehlern – Tests abgebrochen"
	rm -f "$LOG"
	exit 1
fi
if [ $# -gt 0 ]; then
	timeout 600 "$GODOT" --headless --path . -s res://tests/run_tests.gd -- "--filter=$1" >"$LOG" 2>&1
else
	timeout 600 "$GODOT" --headless --path . -s res://tests/run_tests.gd >"$LOG" 2>&1
fi
CODE=$?
grep -vE "^\s*$|^Godot Engine" "$LOG"
if grep -qE "SCRIPT ERROR|Parse Error|^ERROR:" "$LOG"; then
	echo "==> Godot meldet Skriptfehler (siehe oben)"
	CODE=1
fi
rm -f "$LOG"
# Integration scenarios of the race session (headless, ~30 s) – skipped with a filter argument.
if [ $# -eq 0 ] && [ $CODE -eq 0 ]; then
	SLOG=$(mktemp)
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_session.gd >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Integrationsszenarien fehlgeschlagen"
		CODE=1
	fi
	rm -f "$SLOG"
fi
exit $CODE
