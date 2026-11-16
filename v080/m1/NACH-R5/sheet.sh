#!/usr/bin/env bash
# sheet.sh <out.jpg> <crop WxH+X+Y or full> <scale%> <label1> <png1> [<label2> <png2> …]: side by side, labelled
set -uo pipefail
OUT=$1; CROP=$2; SC=$3; shift 3
T=$(mktemp -d /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5/tmp/sheet.XXXX)
i=0
ARGS=()
while [ $# -ge 2 ]; do
	L=$1; P=$2; shift 2
	if [ "$CROP" = "full" ]; then
		convert "$P" -scale "$SC%" "$T/$i.png"
	else
		convert "$P" -crop "$CROP" +repage -scale "$SC%" "$T/$i.png"
	fi
	convert "$T/$i.png" -background '#111' -fill white -font DejaVu-Sans-Bold -pointsize 22 label:"$L" -gravity center +swap -append "$T/l$i.png"
	ARGS+=("$T/l$i.png")
	i=$((i + 1))
done
convert "${ARGS[@]}" -background '#111' -splice 6x0 +append -quality 88 "$OUT"
rm -rf "$T"
echo "$OUT"
