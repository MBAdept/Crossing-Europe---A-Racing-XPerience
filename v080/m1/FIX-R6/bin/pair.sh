#!/usr/bin/env bash
# QA-R6: Arcade | Modern head of a shot at full size with a title line
# usage: pair.sh <head prefix> <NN> <out.jpg> <title>
H=$1; N=$2; OUT=$3; TITLE=$4
lab() { convert "$1" -gravity north -background '#111' -fill white -pointsize 22 -splice 0x30 -annotate +0+4 "$2" "$3"; }
T=$(mktemp -d)
lab "${H}_arcade_${N}.png" "Arcade" $T/a.png
lab "${H}_modern_${N}.png" "Modern (R6 c8b18d1)" $T/c.png
convert $T/a.png $T/c.png +append -gravity north -background '#111' -fill white -pointsize 24 -splice 0x36 -annotate +0+5 "$TITLE" -quality 88 "$OUT"
rm -rf $T
