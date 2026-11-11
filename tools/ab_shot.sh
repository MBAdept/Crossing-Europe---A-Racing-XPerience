#!/usr/bin/env bash
# A/B pictures of the two graphics modes (v0.8.0): the SAME simulation state drawn by the Arcade renderer and by the
# Modern renderer – the picture tool of the renderer packages (docs/renderer-modern.md, "A/B-Bilder").
#
#   tools/ab_shot.sh <out_prefix> [S1|S2|S3|S4|S5] [race scene arguments…]
#
# Two runs of res://scenes/race/race.tscn under Xvfb (software OpenGL, fixed 60 fps) with identical arguments and
# seed: one with --graphics=arcade, one with --graphics=modern, both with --gfx-sync. The race session holds the
# clock of the screenshots while Modern prepares the stage, so equal shot times show equal simulation states
# (tests/race3d/render/check_seam_render.gd "gleiche_zeit"). Arcade runs with --shot-fast (identical pictures, about
# 4× faster); Modern always renders every frame (--shot-fast is taken out of its arguments: what the RenderingServer
# advances while it draws – particles – would stand still).
# Per shot time NN (--shot-times=<s,s,…> seconds after the start, default 2: "LOS!" has faded by then. The stage's
# kilometres are compressed – at 120 km/h the car covers about 0.35 km of the stage per second):
#   <out_prefix>_arcade_NN.png   <out_prefix>_modern_NN.png   the two pictures
#   <out_prefix>_ab_NN.jpg                                    both side by side, labelled (ImageMagick)
# and the logs <out_prefix>_arcade.log / <out_prefix>_modern.log. Exit code 1 when a run fails, a picture is missing
# or Modern fell back to Arcade (the log says why).
#
# Reference positions of the slice (docs/dev/v080_contract.md §4.9.2), Kiel – Hamburg by day, flying start at
# 120 km/h, the autopilot never refuels:
#   S1  km 2 (open Autobahn)      S2  km 13.6 (the first fuel lane opens, the station is at km 15)      S3  km 60
#   S4  km 80 (City Limits, Köhlbrandbrücke; 50 km/h)      S5  km 94 (the finish at km 95)
# Arguments after the position are added to it; a later argument wins over an earlier one with the same name
# (CliArgs keeps the last). Without a position give the arguments yourself, e.g. as in tests/golden/arcade_frames.txt:
#   tools/ab_shot.sh out/s1 S1
#   tools/ab_shot.sh out/s3_nacht S3 --hour=22 --weather=rain --shot-times=2,5
#   tools/ab_shot.sh out/t1 --stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --vehicle=kombi --seed=12 \
#       --autopilot --traffic-warmup --no-countdown --start-speed=120
#   GFX_ARGS="--gfx-preset=high" SCREEN=1280x800 tools/ab_shot.sh out/s4_hoch S4
#
# Environment:
#   GFX_ARGS    extra arguments of the Modern run only (--gfx-preset=high, --gfx=shadows=3,aa=2, --gfx-debug=cover …)
#   SCREEN      size of the virtual screen and of the window (default 1280x720; 1280x800 = Steam Deck: Modern fills
#               it, Arcade keeps 16:9 with bars)
#   GODOT       the Godot binary (godot);  AB_TIMEOUT  seconds per run (default 600)
#   MESA_SHADER_CACHE_DIR  the two runs share one Mesa shader cache; give a folder of your own to keep it warm
#               over many calls (a cold cache costs 0.5–1.9 s per shader variant with llvmpipe)
# Every call uses its own empty, absolute XDG_DATA_HOME per run (no stored settings, never the player's data).
set -uo pipefail
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"   # the comment block above
	exit 2
fi
OUT=$1
shift
case "$OUT" in
/*) ;;
*) OUT="$PWD/$OUT" ;;
esac
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
SCREEN=${SCREEN:-1280x720}
TIMEOUT=${AB_TIMEOUT:-600}
SLICE="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120"
ARGS=()
# shellcheck disable=SC2206
case "${1:-}" in
S1) ARGS=($SLICE --start-km=2) ;;
S2) ARGS=($SLICE --start-km=13.6) ;;
S3) ARGS=($SLICE --start-km=60) ;;
S4) ARGS=($SLICE --start-km=80 --start-speed=50) ;;
S5) ARGS=($SLICE --start-km=94) ;;
esac
[ ${#ARGS[@]} -gt 0 ] && shift
ARGS+=("$@")
if [ ${#ARGS[@]} -eq 0 ]; then
	echo "==> keine Argumente für die Rennszene (eine Position S1–S5 oder --stage=… angeben)" >&2
	exit 2
fi
HAS_TIMES=0
MODERN_ARGS=()
for a in "${ARGS[@]}"; do
	case "$a" in
	--shot-times=*) HAS_TIMES=1 ;;
	--graphics=* | --screenshot=*)
		echo "==> $a gibt dieses Werkzeug selbst vor" >&2
		exit 2
		;;
	esac
	[ "$a" = "--shot-fast" ] || MODERN_ARGS+=("$a")
done
if [ $HAS_TIMES -eq 0 ]; then
	ARGS+=(--shot-times=2)
	MODERN_ARGS+=(--shot-times=2)
fi
mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_ab_shot.XXXXXX")
TMP=$(cd "$TMP" && pwd)   # absolute also with a relative TMPDIR: Godot ignores a relative XDG_DATA_HOME
trap 'rm -rf "$TMP"' EXIT
export MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$TMP/mesa}"
mkdir -p "$MESA_SHADER_CACHE_DIR"
XDG_DATA_HOME="$TMP/import" "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
rm -f "${OUT}"_arcade_[0-9][0-9].png "${OUT}"_modern_[0-9][0-9].png "${OUT}"_ab_[0-9][0-9].jpg

# run <mode> <arguments…>: one run of the race scene; pictures <OUT>_<mode>_NN.png, log <OUT>_<mode>.log
run() {
	local mode=$1
	shift
	local t0=$SECONDS
	mkdir -p "$TMP/xdg_$mode"
	XDG_DATA_HOME="$TMP/xdg_$mode" nice -n 10 timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 ${SCREEN}x24" "$GODOT" --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
		"--screenshot=${OUT}_${mode}" "$@" "--graphics=$mode" --gfx-sync >"${OUT}_${mode}.log" 2>&1
	local code=$?
	local n
	n=$(find "$(dirname "$OUT")" -maxdepth 1 -name "$(basename "$OUT")_${mode}_[0-9][0-9].png" | wc -l)
	printf '    %-7s %2d Bild(er), %3d s\n' "$mode" "$n" $((SECONDS - t0))
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed" "${OUT}_${mode}.log"; then
		echo "==> Lauf $mode fehlgeschlagen (Exit $code$([ $code -eq 124 ] && echo ", Zeitlimit von $TIMEOUT s"), siehe ${OUT}_${mode}.log)" >&2
		grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|^ERROR" "${OUT}_${mode}.log" | head -5 | sed 's/^/      /' >&2
		return 1
	fi
	return 0
}

FAILED=0
run arcade "${ARGS[@]}" --shot-fast || FAILED=1
# shellcheck disable=SC2086
run modern ${MODERN_ARGS[@]+"${MODERN_ARGS[@]}"} ${GFX_ARGS:-} || FAILED=1
if grep -q "Modus Modern nicht möglich" "${OUT}_modern.log"; then
	echo "==> Modern ist auf Arcade zurückgefallen: $(grep -m1 -o "Modus Modern nicht möglich ([^)]*)" "${OUT}_modern.log")" >&2
	FAILED=1
fi

# side by side, labelled: what is shown stands under the pictures
FONT=()
if convert -list font 2>/dev/null | grep -q "Font: DejaVu-Sans-Bold$"; then
	FONT=(-font DejaVu-Sans-Bold)
fi
CAPTION="${ARGS[*]}"
[ -n "${GFX_ARGS:-}" ] && CAPTION="$CAPTION   |   Modern: $GFX_ARGS"
COUNT=0
for a in "${OUT}"_arcade_[0-9][0-9].png; do
	[ -s "$a" ] || continue
	nn=${a##*_}
	nn=${nn%.png}
	m="${OUT}_modern_${nn}.png"
	if [ ! -s "$m" ]; then
		echo "==> Bild $nn fehlt in Modern" >&2
		FAILED=1
		continue
	fi
	w=$(identify -format '%w' "$a")
	if ! convert \
		\( "$a" -background '#10182c' -fill white ${FONT[@]+"${FONT[@]}"} -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade" \) \
		\( "$m" -background '#10182c' -fill white ${FONT[@]+"${FONT[@]}"} -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern" \) \
		-background '#10182c' -gravity North +smush 6 \
		-gravity South -splice 0x34 -fill '#c8d2e6' ${FONT[@]+"${FONT[@]}"} -pointsize 15 \
		-annotate +0+9 "$(printf '%s' "$CAPTION" | cut -c1-$((w / 5)))  ·  Bild $nn" \
		-quality 90 "${OUT}_ab_${nn}.jpg"; then
		echo "==> ImageMagick konnte ${OUT}_ab_${nn}.jpg nicht bauen" >&2
		FAILED=1
		continue
	fi
	COUNT=$((COUNT + 1))
	echo "${OUT}_ab_${nn}.jpg"
done
if [ $COUNT -eq 0 ]; then
	echo "==> kein A/B-Bild entstanden" >&2
	exit 1
fi
[ $FAILED -eq 0 ] || exit 1
