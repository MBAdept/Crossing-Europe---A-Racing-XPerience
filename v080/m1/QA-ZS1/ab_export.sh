#!/usr/bin/env bash
# QA-ZS1: A/B pictures from an EXPORTED Linux build (Xvfb, software OpenGL), same simulation state in both modes:
# fixed 60 fps + --gfx-sync (deterministic, watchdog off), started like a player's build with "-- --stage=…".
#   ab_export.sh <exe> <out_prefix> <modes "arcade modern"> <stage arguments…>
# Pictures <out_prefix>_<mode>_NN.png, logs <out_prefix>_<mode>.log; side by side <out_prefix>_ab_NN.jpg.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
EXE=$1
OUT=$2
MODES=$3
shift 3
mkdir -p "$(dirname "$OUT")"
export MESA_SHADER_CACHE_DIR=${MESA_SHADER_CACHE_DIR:-$S/mesa_ab}
mkdir -p "$MESA_SHADER_CACHE_DIR"
SCREEN=${SCREEN:-1280x720}
for mode in $MODES; do
	X="$S/xdg_ab/$(basename "$OUT")_$mode"
	rm -rf "$X"
	mkdir -p "$X"
	rm -f "${OUT}_${mode}"_[0-9][0-9].png
	t0=$SECONDS
	XDG_DATA_HOME="$X" nice -n 5 timeout 1500 xvfb-run -a -s "-screen 0 ${SCREEN}x24" "$EXE" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 -- "$@" --graphics=$mode --sound=$mode --gfx-sync --audio-sync \
		"--screenshot=${OUT}_${mode}" >"${OUT}_${mode}.log" 2>&1
	code=$?
	n=$(ls "${OUT}_${mode}"_[0-9][0-9].png 2>/dev/null | wc -l)
	echo "$(basename "$OUT") $mode: exit $code, $n Bilder, $((SECONDS - t0)) s; $(grep -cE 'SCRIPT ERROR|Parse Error|SHADER ERROR' "${OUT}_${mode}.log") Skriptfehler; $(grep -o 'Modus Modern nicht möglich[^)]*)' "${OUT}_${mode}.log" | head -1)"
	rm -rf "$X"
done
case "$MODES" in
*arcade*modern*)
	for a in "${OUT}"_arcade_[0-9][0-9].png; do
		[ -s "$a" ] || continue
		nn=${a##*_}
		nn=${nn%.png}
		m="${OUT}_modern_${nn}.png"
		[ -s "$m" ] || { echo "Bild $nn fehlt in Modern"; continue; }
		convert \( "$a" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x40 -annotate +0+6 "Arcade  $nn" \) \
			\( "$m" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x40 -annotate +0+6 "Modern  $nn" \) \
			-background '#10182c' +smush 6 -quality 88 "${OUT}_ab_${nn}.jpg"
	done
	;;
esac
