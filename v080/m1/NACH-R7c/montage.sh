#!/bin/bash
# montage.sh <out.png|jpg> <crop WxH+X+Y or "full"> <scale %> <label1> <png1> [<label2> <png2> ...]
OUT=$1
CROP=$2
SC=$3
shift 3
args=()
while [ $# -ge 2 ]; do
	lab=$1
	f=$2
	shift 2
	if [ "$CROP" = "full" ]; then
		args+=( \( "$f" -resize "${SC}%" -background '#10182c' -fill white -pointsize 22 -gravity North -splice 0x32 -annotate +0+4 "$lab" \) )
	else
		args+=( \( "$f" -gravity NorthWest -crop "$CROP" +repage -filter point -resize "${SC}%" -background '#10182c' -fill white -pointsize 22 -gravity North -splice 0x32 -annotate +0+4 "$lab" \) )
	fi
done
convert "${args[@]}" -background '#10182c' +smush 6 -quality 88 "$OUT"
