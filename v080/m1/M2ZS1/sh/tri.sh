#!/usr/bin/env bash
# tri.sh <out.jpg> <title> <arcade.png> <zs1.png|-> <m2zs1.png>  – Arcade | ZS1 | M2ZS1, labelled, half size
set -uo pipefail
OUT=$1; TITLE=$2; A=$3; Z=$4; M=$5
T=$(mktemp -d)
lab() {   # lab <in> <label> <out>
	convert "$1" -resize 50% -gravity north -background '#101820' -splice 0x30 -fill white -pointsize 20 -annotate +0+4 "$2" "$3"
}
lab "$A" "Arcade" "$T/a.png"
if [ "$Z" != "-" ] && [ -f "$Z" ]; then
	lab "$Z" "Modern ZS1 (Testbuild, 39849f0)" "$T/z.png"
else
	convert "$T/a.png" -fill '#101820' -draw "rectangle 0,0 10000,10000" -fill white -pointsize 20 -gravity center -annotate +0+0 "ZS1: kein Bild" "$T/z.png"
fi
lab "$M" "Modern M2ZS1 (M2 + ZS1)" "$T/m.png"
convert "$T/a.png" "$T/z.png" "$T/m.png" +append -gravity south -background '#101820' -splice 0x26 -fill '#c8d0d8' -pointsize 16 -annotate +0+4 "$TITLE" -quality 88 "$OUT"
rm -rf "$T"
