#!/bin/bash
# tri.sh <out.jpg> <title> <img1> <label1> <img2> <label2> [<img3> <label3>]: labelled side-by-side sheet at 50 %
OUT=$1; TITLE=$2; shift 2
ARGS=()
while [ $# -ge 2 ]; do
  ARGS+=( \( "$1" -resize 50% -background '#10182c' -fill white -font DejaVu-Sans-Bold -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "$2" \) )
  shift 2
done
convert "${ARGS[@]}" -background '#10182c' +smush 4 -gravity South -splice 0x26 -fill '#c8d2e6' -font DejaVu-Sans -pointsize 14 -annotate +0+5 "$TITLE" -quality 88 "$OUT"
