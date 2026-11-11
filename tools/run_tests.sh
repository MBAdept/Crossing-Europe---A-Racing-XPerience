#!/usr/bin/env bash
# Runs all headless tests in one pass. Usage: tools/run_tests.sh [filter]
# Fails if a test fails OR Godot reports a script/parse error.
#   1. compiles every script (tests/check_scripts.gd)
#   2. unit tests: every tests/unit/**/test_*.gd (with a filter: only files whose path contains it)
#   3. without a filter: the integration scenarios of the race scene and the menus, the network-wide checks
#   4. v0.8.0, generic hook: every tests/race3d/check_*.gd and tests/sim/modern_*.gd runs on its own with
#      "godot --headless --path . -s <file>", prints "CHECK <name> OK|FEHLER" lines and returns an exit code.
#      A new check only needs its file – nobody edits this script for it. (With a filter: the files whose name
#      contains it.) A file fails on an exit code other than 0, on a script error, on a "CHECK <name> FEHLER" line
#      and when it prints no "CHECK <name> OK" line at all – the exit code alone is not trusted.
# Everything that needs OpenGL is in tools/run_render_checks.sh, the Arcade pictures in tools/golden.sh.
# The tests never see the player's own data: user:// lies in a temporary folder (no stored settings – in particular
# no stored graphics mode –, no override of the configuration) unless the caller sets XDG_DATA_HOME to an ABSOLUTE
# path. Godot ignores a relative XDG_DATA_HOME and falls back to ~/.local/share – the real user folder –, so a
# relative value is not used either.
# The runs of the whole game and of the race scene name their graphics mode: -- --graphics=arcade.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
OWN_HOME=""
case "${XDG_DATA_HOME:-}" in
/*) ;;
*)
	[ -n "${XDG_DATA_HOME:-}" ] && echo "==> XDG_DATA_HOME=\"$XDG_DATA_HOME\" ist kein absoluter Pfad (Godot würde ihn ignorieren) – die Tests nutzen einen temporären Ordner"
	OWN_HOME=$(mktemp -d "${TMPDIR:-/tmp}/ce_tests.XXXXXX")
	OWN_HOME=$(cd "$OWN_HOME" && pwd)   # absolute also with a relative TMPDIR
	export XDG_DATA_HOME="$OWN_HOME"
	;;
esac
LOG=$(mktemp)
SLOG=$(mktemp)
trap 'rm -f "$LOG" "$SLOG"; [ -n "$OWN_HOME" ] && rm -rf "$OWN_HOME"' EXIT
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --path . -s res://tests/check_scripts.gd >"$LOG" 2>&1
grep -E "KAPUTT|geprüft|SCRIPT ERROR|Parse Error|at: GDScript" "$LOG" | head -60
if grep -qE "KAPUTT" "$LOG"; then
	echo "==> Skripte mit Parse-Fehlern – Tests abgebrochen"
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
# Integration scenarios of the race session (headless, ~45 s) and the network-wide police escape check
# (~60 s) – skipped with a filter argument.
if [ $# -eq 0 ] && [ $CODE -eq 0 ]; then
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_session.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Integrationsszenarien fehlgeschlagen"
		CODE=1
	fi
	# Attract mode end to end (~25 s): idle timer, demo in the race scene, ended by key/gamepad/click without a
	# menu action, effect buses muted and restored, nothing saved
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_attract.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Modus fehlgeschlagen"
		CODE=1
	fi
	# … and the same in the mode "Modern" (~30 s): the demo timer starts when the scene is prepared (A-2)
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_attract.gd -- --graphics=modern >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Modus (Modern) fehlgeschlagen"
		CODE=1
	fi
	# Gamepad end to end (~10 s): one step per stick push, held D-pad repeats, LB/RB, a second pad, typing into the
	# name field, the on-screen keyboard, the quit question, driving / pausing with pad 2, vibration, interpolated view
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_menu_pad.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Gamepad-Prüfung fehlgeschlagen"
		CODE=1
	fi
	# The options in two pages with real pad events (~2 s, v0.8.0 UI1): LB/RB, the quality rows dimmed in Arcade
	timeout 300 "$GODOT" --headless --path . -s res://tests/race/check_options_tabs.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Optionen-Prüfung fehlgeschlagen"
		CODE=1
	fi
	# Every attract demo scene for its full 30 s (~2 min): ends by time (not at the finish), no collision, no
	# guardrail, nothing close in front, no crawl – pins the tuned scene values of attract.scenes
	timeout 600 "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd -- --graphics=arcade >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Szenen fehlgeschlagen"
		CODE=1
	fi
	# … and every demo scene in the mode "Modern" (same simulation: same verdicts)
	timeout 600 "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/race/check_attract_scenes.gd -- --graphics=modern >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK" "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Attract-Szenen (Modern) fehlgeschlagen"
		CODE=1
	fi
	# Police escapes on the whole network with the curve physics (~60 s): every radar × car × dry day / rain night
	timeout 600 "$GODOT" --headless --path . -s res://tests/sim/check_escapes.gd >"$SLOG" 2>&1
	SCODE=$?
	grep -E "^CHECK|^    " "$SLOG"
	if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR" "$SLOG"; then
		echo "==> Polizeiflucht im Streckennetz fehlgeschlagen"
		CODE=1
	fi
fi
# v0.8.0 – generic hook for the headless checks of the graphics mode "Modern" (seam, world model, fairness, …)
if [ $CODE -eq 0 ]; then
	for f in $(ls tests/race3d/check_*.gd tests/sim/modern_*.gd 2>/dev/null | sort); do
		if [ $# -gt 0 ] && [[ "$(basename "$f")" != *"$1"* ]]; then
			continue
		fi
		timeout 600 "$GODOT" --headless --path . -s "res://$f" >"$SLOG" 2>&1
		SCODE=$?
		grep -E "^CHECK" "$SLOG"
		if [ $SCODE -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$SLOG" || grep -qE "^CHECK +[^ ]+ +FEHLER" "$SLOG" \
			|| ! grep -qE "^CHECK +[^ ]+ +OK" "$SLOG"; then
			echo "==> $f fehlgeschlagen (Exit $SCODE)"
			grep -E -A4 "SCRIPT ERROR|Parse Error" "$SLOG" | head -20
			[ $SCODE -eq 124 ] && echo "    Zeitlimit überschritten"
			grep -qE "^CHECK +[^ ]+ +(OK|FEHLER)" "$SLOG" || echo "    keine Zeile \"CHECK <name> OK|FEHLER\" ausgegeben"
			CODE=1
		fi
	done
fi
echo "==> Tests $([ $CODE -eq 0 ] && echo bestanden || echo FEHLGESCHLAGEN) ($SECONDS s)"
exit $CODE
