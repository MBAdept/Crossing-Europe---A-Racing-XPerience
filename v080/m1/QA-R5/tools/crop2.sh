#!/usr/bin/env bash
# crop2.sh <out.jpg> <geometry WxH+X+Y> <scale%> <png...>: the same crop of several pictures side by side, labelled
out=$1; geo=$2; sc=$3; shift 3
args=()
for f in "$@"; do
	lbl=$(basename "$f" .png)
	args+=("(" "$f" -crop "$geo" +repage -resize "$sc%" -gravity north -background '#111' -fill white -pointsize 18 -splice 0x24 -annotate +0+2 "$lbl" ")")
done
convert "${args[@]}" +append -quality 90 "$out"
