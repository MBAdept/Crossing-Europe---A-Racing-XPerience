#!/bin/bash
# NACH-R7a comparison sheet: sheet.sh <name> <frame NN> -> deliver/NACH-R7a/vergleich/<name>_<NN>.jpg
# Arcade (this run) | R7a 509bb16 (R7a's own picture, byte-identical renders per QA-R7a) | head 4a43944 (if rendered) |
# FIX-R7a push-out 12 m on head (FIX-R7a's picture) | m3 = head + FIX-RINT + FIX-R7c eb97a98 + patch B (this run)
V=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver
D=$V/NACH-R7a
n=$1; f=${2:-00}
mkdir -p $D/vergleich
args=()
add() { [ -f "$2" ] && args+=(-label "$1" "$2"); }
add "Arcade" $D/m3/${n}_high_arcade_$f.png
r7a=$V/R7a/ab_boegen/${n}_high_modern_$f.png
[ -f "$r7a" ] || r7a=$V/R7a/bilder/${n}_high_modern_$f.png
add "R7a 509bb16" "$r7a"
add "Kopf 4a43944 (ohne Patch)" $D/kopf/${n}_high_modern_$f.png
fx=$V/FIX-R7a/hinausschieben/${n}_b12_high_modern_$f.png
[ -f "$fx" ] || fx=$V/FIX-R7a/hinausschieben/${n}_high_modern_$f.png
add "FIX-R7a Kopf+Patch (deren Bild)" "$fx"
add "m3: Kopf+FIX-RINT+FIX-R7c+Patch" $D/m3/${n}_high_modern_$f.png
montage "${args[@]}" -tile "$(( ${#args[@]} / 3 ))x1" -geometry 960x540+4+4 -pointsize 22 $D/vergleich/${n}_$f.jpg
echo $D/vergleich/${n}_$f.jpg
