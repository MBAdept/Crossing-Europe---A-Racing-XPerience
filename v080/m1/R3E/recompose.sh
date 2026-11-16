#!/usr/bin/env bash
# Re-composes an A/B picture from its two PNGs with a new caption (same layout as ab_inject.sh).
#   recompose.sh <out_prefix> <caption>
set -uo pipefail
OUT=$1
CAP=$2
FONT=(-font DejaVu-Sans-Bold)
convert \( "${OUT}_arcade.png" -background '#10182c' -fill white "${FONT[@]}" -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade" \) \
	\( "${OUT}_modern.png" -background '#10182c' -fill white "${FONT[@]}" -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern" \) \
	-background '#10182c' -gravity North +smush 6 -gravity South -splice 0x34 -fill '#c8d2e6' "${FONT[@]}" -pointsize 15 \
	-annotate +0+9 "$CAP" -quality 90 "${OUT}_ab.jpg"
echo "${OUT}_ab.jpg"
