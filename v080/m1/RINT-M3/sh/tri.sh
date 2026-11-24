#!/bin/bash
# tri.sh <out.jpg> <arcade.png> <base_modern.png> <head_modern.png> [label base] [label head]: three panels side by side
out=$1; a=$2; b=$3; h=$4; lb=${5:-"Modern 3248211 (Basis)"}; lh=${6:-"Modern RINT-M3"}
tmp=$(mktemp -d)
convert "$a" -resize 960x -gravity North -background '#14181f' -splice 0x34 -fill white -pointsize 22 -annotate +0+5 "Arcade" $tmp/a.png
convert "$b" -resize 960x -gravity North -background '#14181f' -splice 0x34 -fill white -pointsize 22 -annotate +0+5 "$lb" $tmp/b.png
convert "$h" -resize 960x -gravity North -background '#14181f' -splice 0x34 -fill white -pointsize 22 -annotate +0+5 "$lh" $tmp/h.png
convert $tmp/a.png $tmp/b.png $tmp/h.png +append -quality 88 "$out"
rm -rf $tmp
