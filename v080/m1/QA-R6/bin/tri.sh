#!/usr/bin/env bash
# QA-R6: triptych Arcade | Modern base 6e48405 | Modern head c8b18d1 of the same shot (half size, labelled)
# usage: tri.sh <head prefix> <base prefix> <NN> <out.jpg> <title>
H=$1; B=$2; N=$3; OUT=$4; TITLE=$5
lab() { convert "$1" -resize 50% -gravity north -background '#111' -fill white -pointsize 18 -splice 0x26 -annotate +0+3 "$2" "$3"; }
T=$(mktemp -d)
lab "${H}_arcade_${N}.png" "Arcade" $T/a.png
lab "${B}_modern_${N}.png" "Modern Basis 6e48405" $T/b.png
lab "${H}_modern_${N}.png" "Modern R6 c8b18d1" $T/c.png
convert $T/a.png $T/b.png $T/c.png +append -gravity north -background '#111' -fill white -pointsize 20 -splice 0x30 -annotate +0+4 "$TITLE" -quality 88 "$OUT"
rm -rf $T
