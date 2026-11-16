#!/usr/bin/env bash
# R6: an A/B sheet – the given A/B pictures (tools/ab_shot.sh, Arcade left / Modern right) one under the other, with a
# title strip. Usage: sheet.sh <out.jpg> "<title>" <picture> …
OUT=$1
TITLE=$2
shift 2
TMP=$(mktemp -d)
i=0
for f in "$@"; do
	convert "$f" -resize 1600x "$TMP/$(printf '%02d' $i).png"
	i=$((i + 1))
done
convert -size 1600x56 xc:'#0f1626' -fill white -font DejaVu-Sans-Bold -pointsize 28 -gravity center -annotate +0+0 "$TITLE" "$TMP/title.png"
convert "$TMP/title.png" "$TMP"/[0-9][0-9].png -append -quality 88 "$OUT"
rm -rf "$TMP"
identify "$OUT"
