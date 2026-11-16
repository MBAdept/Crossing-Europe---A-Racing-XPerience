#!/usr/bin/env bash
# QA-ZS1: contact sheet of A/B frames: sheet.sh <prefix> <out.jpg> "<nn>:<label>" ...
# Each row: Arcade | Modern of frame nn at 50 %, labelled.
set -uo pipefail
P=$1
OUTF=$2
shift 2
TMPD=$(mktemp -d /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1/sheet.XXXXXX)
rows=()
i=0
for pair in "$@"; do
	nn=${pair%%:*}
	t=${pair#*:}
	convert "${P}_arcade_$nn.png" -resize 50% -background '#10182c' -fill white -pointsize 18 -gravity North -splice 0x28 -annotate +0+4 "Arcade – $t" "$TMPD/a.png"
	convert "${P}_modern_$nn.png" -resize 50% -background '#10182c' -fill white -pointsize 18 -gravity North -splice 0x28 -annotate +0+4 "Modern – $t" "$TMPD/m.png"
	convert "$TMPD/a.png" "$TMPD/m.png" +append "$TMPD/row_$i.png"
	rows+=("$TMPD/row_$i.png")
	i=$((i + 1))
done
convert "${rows[@]}" -append -quality 85 "$OUTF"
rm -rf "$TMPD"
identify "$OUTF"
