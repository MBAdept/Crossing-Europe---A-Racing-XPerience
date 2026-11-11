#!/usr/bin/env bash
# Render checks: everything that needs a real renderer (not part of tools/run_tests.sh, which stays headless).
# Runs under Xvfb with software OpenGL at a fixed 60 fps.
#   tools/run_render_checks.sh [arcade|modern|all] [filter]
#     arcade  the render checks of the Arcade renderer (tests/race/check_glow_occlusion.gd, check_sprite_flip.gd),
#             started with -- --graphics=arcade
#     modern  every tests/race3d/render/check_*.gd, started with -- --graphics=modern --gfx-sync --audio-sync
#     all     both (default)
#     filter  only files whose name contains it
# Each check prints its own lines ("RENDER-CHECK <name> OK|FEHLER …", the Arcade checks "GLOW-CHECK …" /
# "FLIP-CHECK …"); this script adds one "RENDER-CHECK-DATEI <file> OK|FEHLER" line per file. Exit code 1 if a file
# failed, reported a script error or a shader that did not compile ("SHADER ERROR", "Shader compilation failed" –
# such a material simply draws nothing), or printed no check line at all.
# All runs of one call share one XDG_DATA_HOME and one MESA_SHADER_CACHE_DIR (a cold shader cache costs 0.5–1.9 s
# per shader variant with llvmpipe). Environment: GODOT, RENDER_CHECK_TIMEOUT (seconds per file, default 900).
# XDG_DATA_HOME of the caller is used only if it is an absolute path (Godot ignores a relative one and falls back to
# ~/.local/share – the real user folder); otherwise user:// lies in a temporary folder.
# A new render check only needs its file in tests/race3d/render/ – nobody edits this script for it.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
WHAT=${1:-all}
FILTER=${2:-}
TIMEOUT=${RENDER_CHECK_TIMEOUT:-900}
case "$WHAT" in
arcade | modern | all) ;;
*)
	sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
	;;
esac
OWN_HOME=""
case "${XDG_DATA_HOME:-}" in
/*) ;;
*)
	[ -n "${XDG_DATA_HOME:-}" ] && echo "==> XDG_DATA_HOME=\"$XDG_DATA_HOME\" ist kein absoluter Pfad (Godot würde ihn ignorieren) – die Prüfungen nutzen einen temporären Ordner"
	OWN_HOME=$(mktemp -d "${TMPDIR:-/tmp}/ce_render_checks.XXXXXX")
	OWN_HOME=$(cd "$OWN_HOME" && pwd)   # absolute also with a relative TMPDIR
	export XDG_DATA_HOME="$OWN_HOME"
	;;
esac
export MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$XDG_DATA_HOME/mesa_shader_cache}"
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
LOG=$(mktemp)
trap 'rm -f "$LOG"; [ -n "$OWN_HOME" ] && rm -rf "$OWN_HOME"' EXIT
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

FAILED=0
COUNT=0
# run_file <file> <game args…>
run_file() {
	local file=$1
	shift
	if [ -n "$FILTER" ] && [[ "$(basename "$file")" != *"$FILTER"* ]]; then
		return
	fi
	COUNT=$((COUNT + 1))
	local t0=$SECONDS
	nice -n 10 timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "res://$file" -- "$@" >"$LOG" 2>&1
	local code=$?
	grep -E "^(RENDER-CHECK|GLOW-CHECK|FLIP-CHECK)|SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed" "$LOG"
	local verdict="OK"
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed" "$LOG" \
		|| ! grep -qE "^(RENDER-CHECK|GLOW-CHECK|FLIP-CHECK)" "$LOG"; then
		verdict="FEHLER"
		FAILED=$((FAILED + 1))
		[ $code -eq 124 ] && echo "    Zeitlimit von $TIMEOUT s überschritten"
		grep -E "^ERROR|^   at:" "$LOG" | head -6 | sed 's/^/    /'
	fi
	printf 'RENDER-CHECK-DATEI %-48s %s  (Exit %d, %d s)\n' "$file" "$verdict" "$code" $((SECONDS - t0))
}

if [ "$WHAT" = arcade ] || [ "$WHAT" = all ]; then
	for f in tests/race/check_glow_occlusion.gd tests/race/check_sprite_flip.gd; do
		run_file "$f" --graphics=arcade
	done
fi
if [ "$WHAT" = modern ] || [ "$WHAT" = all ]; then
	for f in $(find tests/race3d/render -maxdepth 1 -name 'check_*.gd' 2>/dev/null | sort); do
		run_file "$f" --graphics=modern --gfx-sync --audio-sync
	done
fi
if [ $COUNT -eq 0 ]; then
	echo "==> keine Render-Prüfung gefunden (${WHAT}${FILTER:+, Filter \"$FILTER\"})"
	exit 1
fi
echo "==> $((COUNT - FAILED)) von $COUNT Render-Prüfdateien in Ordnung"
[ $FAILED -eq 0 ]
