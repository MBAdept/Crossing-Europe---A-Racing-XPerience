#!/usr/bin/env bash
# combine.sh <out.jpg> <caption> <label1> <img1> [<label2> <img2> [<label3> <img3>]] – pictures side by side, labelled
set -uo pipefail
OUT=$1; CAP=$2; shift 2
ARGS=()
while [ $# -ge 2 ]; do
	ARGS+=( \( "$2" -background '#10182c' -fill white -font DejaVu-Sans-Bold -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "$1" \) )
	shift 2
done
convert "${ARGS[@]}" -background '#10182c' -gravity North +smush 6 -gravity South -splice 0x34 -fill '#c8d2e6' \
	-font DejaVu-Sans-Bold -pointsize 15 -annotate +0+9 "$CAP" -quality 88 "$OUT" && echo "$OUT"
