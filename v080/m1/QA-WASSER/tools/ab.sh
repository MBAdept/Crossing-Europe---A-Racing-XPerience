#!/usr/bin/env bash
# QA-WASSER: Arcade | Modern from the exported build, same arguments, side by side.
#   ab.sh <linux|windows> <out_prefix> <WxH> <label> [game args …]     (MODES="modern" to skip Arcade)
set -uo pipefail
T=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER/tools
PLAT=$1
OUT=$2
SCREEN=$3
LABEL=$4
shift 4
for mode in ${MODES:-arcade modern}; do
	"$T/xshot.sh" "$PLAT" "$OUT" "$SCREEN" "$mode" "$@"
done
for a in "${OUT}"_arcade_[0-9][0-9].png; do
	[ -s "$a" ] || continue
	nn=${a##*_}
	nn=${nn%.png}
	m="${OUT}_modern_${nn}.png"
	[ -s "$m" ] || { echo "Modern-Bild $nn fehlt"; continue; }
	convert \( "$a" -background '#10182c' -fill white -font DejaVu-Sans-Bold -pointsize 24 -gravity North -splice 0x40 -annotate +0+6 "Arcade ($PLAT-Export)" \) \
		\( "$m" -background '#10182c' -fill white -font DejaVu-Sans-Bold -pointsize 24 -gravity North -splice 0x40 -annotate +0+6 "Modern ($PLAT-Export)" \) \
		-background '#10182c' -gravity North +smush 6 \
		-gravity South -splice 0x30 -fill '#c8d2e6' -font DejaVu-Sans -pointsize 15 -annotate +0+7 "$LABEL · Bild $nn" \
		-quality 88 "${OUT}_ab_${nn}.jpg" && echo "${OUT}_ab_${nn}.jpg"
done
