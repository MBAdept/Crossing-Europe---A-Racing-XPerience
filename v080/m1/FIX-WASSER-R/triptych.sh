#!/usr/bin/env bash
# FIX-WASSER-R: Arcade | Modern vorher (0ad9012) | Modern nachher (FIX-WASSER-R) for one picture series
#   triptych.sh <name> "<caption>" [labels of the shots separated by ;]
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-WASSER-R/bilder
mkdir -p "$D"
NAME=$1
CAP=$2
IFS=';' read -r -a LABELS <<< "${3:-}"
FONT=()
FONTS=$(convert -list font 2>/dev/null || true)
case "$FONTS" in
*"Font: DejaVu-Sans-Bold"*) FONT=(-font DejaVu-Sans-Bold) ;;
esac
for a in "$S/shots/${NAME}"_arcade_[0-9][0-9].png; do
	[ -s "$a" ] || continue
	nn=${a##*_}
	nn=${nn%.png}
	b=$S/before/${NAME}_modern_$nn.png
	m=$S/shots/${NAME}_modern_$nn.png
	if [ ! -s "$b" ] || [ ! -s "$m" ]; then
		echo "fehlt: $NAME $nn"
		continue
	fi
	lab=""
	i=$((10#$nn))
	[ $i -lt ${#LABELS[@]} ] && lab=" – ${LABELS[$i]}"
	same=""
	if cmp -s "$b" "$m"; then same="  (vorher = nachher, bitgleich)"; fi
	convert \( "$a" -resize 50% -background '#10182c' -fill white "${FONT[@]}" -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "Arcade" \) \
		\( "$b" -resize 50% -background '#10182c' -fill white "${FONT[@]}" -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "Modern vorher (0ad9012)" \) \
		\( "$m" -resize 50% -background '#10182c' -fill white "${FONT[@]}" -pointsize 18 -gravity North -splice 0x30 -annotate +0+5 "Modern nachher (FIX-WASSER-R)" \) \
		-background '#10182c' +smush 4 -gravity South -splice 0x26 -fill '#c8d2e6' "${FONT[@]}" -pointsize 14 \
		-annotate +0+6 "${CAP}${lab}${same}" \
		-quality 88 "$D/${NAME}_${nn}_arcade_vorher_nachher.jpg" && echo "$D/${NAME}_${nn}_arcade_vorher_nachher.jpg${same}"
done
