#!/usr/bin/env bash
# zoom.sh <prefix> <out.png> <crop WxH+X+Y> <scale %>: labelled zoom triple Arcade | R7b | FIX-R7b
P=$1
OUT=$2
CROP=$3
SC=${4:-300}
convert -respect-parentheses \
	\( "${P}_arcade_00.png" -crop "$CROP" +repage -filter point -resize "${SC}%" -background '#10182c' -fill white -pointsize 22 -gravity North -splice 0x36 -annotate +0+6 "Arcade" \) \
	\( "${P}_basis_00.png" -crop "$CROP" +repage -filter point -resize "${SC}%" -background '#10182c' -fill white -pointsize 22 -gravity North -splice 0x36 -annotate +0+6 "R7b 2c154bc" \) \
	\( "${P}_modern_00.png" -crop "$CROP" +repage -filter point -resize "${SC}%" -background '#10182c' -fill white -pointsize 22 -gravity North -splice 0x36 -annotate +0+6 "FIX-R7b c50d58f" \) \
	-background '#10182c' -gravity North +smush 6 "$OUT"
