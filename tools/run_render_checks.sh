#!/usr/bin/env bash
# Render checks: everything that needs a real renderer (not part of tools/run_tests.sh, which stays headless).
# Runs under Xvfb with software OpenGL at a fixed 60 fps.
#   tools/run_render_checks.sh [arcade|modern|audio|all] [filter]
#     arcade  the render checks of the Arcade renderer (tests/race/check_glow_occlusion.gd, check_sprite_flip.gd),
#             started with -- --graphics=arcade
#     modern  every tests/race3d/render/check_*.gd, started with -- --graphics=modern --gfx-sync --audio-sync
#     audio   the Movie-Maker scenarios of the Modern sound (tests/race/check_audio_modern.gd, AU-E), started with
#             -- --graphics=arcade --sound=modern --audio-sync (the sound does not read the renderer; the cheap picture
#             drives it, about 15 min)
#     all     all three (default)
#     filter  only files whose name contains it
# Each check prints its own lines ("RENDER-CHECK <name> OK|FEHLER …", the Arcade checks "GLOW-CHECK …" /
# "FLIP-CHECK …", the sound "AUDIO-CHECK …"); this script adds one "RENDER-CHECK-DATEI <file> OK|FEHLER|ZEITLIMIT"
# line per file (ZEITLIMIT: the file ran into its time limit and gave no verdict – it counts as failed, but says it is
# not a broken rule; FIX-M2, QA-M2-SYSTEM M2S-01). A file may raise its own limit with a line
# "## render-check-timeout: <s>" and add options for Godot itself with a line "## render-check-godot: <options>"
# ({tmp} = a temporary folder of this call, removed after the file; e.g. Movie Maker: --write-movie {tmp}/x.avi – a
# later --resolution wins over the default). Exit code 1 if a file
# failed, reported a script error or a shader that did not compile ("SHADER ERROR", "Shader compilation failed" –
# such a material simply draws nothing), an instance the global shader buffer refused ("Too many instances using
# shader instance variables" – it is drawn with another instance's values, RINT-B), or printed no check line at all.
# All runs of one call share one XDG_DATA_HOME and one MESA_SHADER_CACHE_DIR (a cold shader cache costs 0.5–1.9 s
# per shader variant with llvmpipe). Environment: GODOT, RENDER_CHECK_TIMEOUT (seconds per file, default 900).
# XDG_DATA_HOME of the caller is used only if it is an absolute path (Godot ignores a relative one and falls back to
# ~/.local/share – the real user folder); otherwise user:// lies in a temporary folder.
# A new render check only needs its file in tests/race3d/render/ – nobody edits this script for it (the audio group
# lists its one file below).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
WHAT=${1:-all}
FILTER=${2:-}
TIMEOUT=${RENDER_CHECK_TIMEOUT:-900}
case "$WHAT" in
arcade | modern | audio | all) ;;
*)
	sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
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
	local limit=$TIMEOUT
	local own
	own=$(grep -m1 -oE '^## render-check-timeout: [0-9]+' "$file" | grep -oE '[0-9]+$')
	if [ -n "$own" ] && [ "$own" -gt "$limit" ]; then
		limit=$own
	fi
	local extra=()
	local own_args
	own_args=$(grep -m1 -E '^## render-check-godot: ' "$file" | sed 's/^## render-check-godot: //')
	if [ -n "$own_args" ]; then
		mkdir -p "$XDG_DATA_HOME/render_check_tmp"
		read -r -a extra <<<"${own_args//\{tmp\}/$XDG_DATA_HOME/render_check_tmp}"
	fi
	nice -n 10 timeout "$limit" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 "${extra[@]}" -s "res://$file" -- "$@" >"$LOG" 2>&1
	local code=$?
	rm -rf "$XDG_DATA_HOME/render_check_tmp"
	grep -E "^(RENDER-CHECK|GLOW-CHECK|FLIP-CHECK|AUDIO-CHECK)|SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Too many instances using shader instance variables" "$LOG"
	local verdict="OK"
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Too many instances using shader instance variables" "$LOG" \
		|| ! grep -qE "^(RENDER-CHECK|GLOW-CHECK|FLIP-CHECK|AUDIO-CHECK)" "$LOG"; then
		verdict="FEHLER"
		FAILED=$((FAILED + 1))
		if [ $code -eq 124 ]; then
			verdict="ZEITLIMIT"
			echo "    Zeitlimit von $limit s überschritten – kein Ergebnis (keine Regel verletzt gemeldet; Last der Maschine?)"
		fi
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
if [ "$WHAT" = audio ] || [ "$WHAT" = all ]; then
	run_file tests/race/check_audio_modern.gd --graphics=arcade --sound=modern --audio-sync
fi
if [ $COUNT -eq 0 ]; then
	echo "==> keine Render-Prüfung gefunden (${WHAT}${FILTER:+, Filter \"$FILTER\"})"
	exit 1
fi
echo "==> $((COUNT - FAILED)) von $COUNT Render-Prüfdateien in Ordnung"
[ $FAILED -eq 0 ]
