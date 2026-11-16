#!/usr/bin/env bash
# FIX-ZS1: Arcade | Modern vorher | Modern nachher for the five moments of the standing start (ab_start.sh shot times)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-ZS1/bilder
mkdir -p "$D"
LABELS=("1 s im Countdown" "3 s (Ende des Countdowns)" "0,7 s nach LOS" "1,5 s nach LOS" "4 s nach LOS")
FONT=()
convert -list font 2>/dev/null | grep -q "Font: DejaVu-Sans-Bold" && FONT=(-font DejaVu-Sans-Bold)
for i in 0 1 2 3 4; do
	nn=$(printf %02d "$i")
	a=$S/shots/kh0_arcade_$nn.png
	b=$S/before/kh0_modern_$nn.png
	m=$S/shots/kh0_modern_$nn.png
	if [ ! -s "$a" ] || [ ! -s "$b" ] || [ ! -s "$m" ]; then
		echo "fehlt: $nn"
		continue
	fi
	convert \( "$a" -resize 50% -background '#10182c' -fill white "${FONT[@]}" -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "Arcade" \) \
		\( "$b" -resize 50% -background '#10182c' -fill white "${FONT[@]}" -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "Modern vorher (92ece73)" \) \
		\( "$m" -resize 50% -background '#10182c' -fill white "${FONT[@]}" -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "Modern nachher (FIX-ZS1)" \) \
		-background '#10182c' +smush 4 -gravity South -splice 0x26 -fill '#c8d2e6' "${FONT[@]}" -pointsize 14 \
		-annotate +0+6 "Kiel – Hamburg, stehender Start bei km 0, Limousine, 12 Uhr, Modern Mittel – ${LABELS[$i]}" \
		-quality 88 "$D/start_km0_${nn}_arcade_vorher_nachher.jpg" && echo "$D/start_km0_${nn}_arcade_vorher_nachher.jpg"
done
