#!/bin/bash
# compose.sh <name> <nn> <out basename> – Arcade | R4 (QA-R4's head picture) | FIX-R4, labelled, 50 %
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1
D=$S/../deliver/FIX-R4/bilder
T=$S/FIX-R4/tmpc
mkdir -p "$D" "$T"
N=$1
NN=$2
OUT=$3
A=$S/QA-R4/shots/head/${N}_arcade_$NN.png
R=$S/QA-R4/shots/head/${N}_modern_$NN.png
F=$S/FIX-R4/pics/${N}_modern_$NN.png
lab() {
	convert "$1" -resize 50% -background '#10182c' -fill white -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "$2" "$3"
}
lab "$A" "Arcade" "$T/a.png"
lab "$R" "Modern R4 (7f0eae2)" "$T/r.png"
lab "$F" "Modern FIX-R4" "$T/f.png"
convert "$T/a.png" "$T/r.png" "$T/f.png" -background '#10182c' +smush 4 -quality 88 "$D/$OUT.jpg"
rm -f "$T/a.png" "$T/r.png" "$T/f.png"
echo "$D/$OUT.jpg"
