#!/usr/bin/env bash
# R6: single frames of a clip to look at. Usage: clipframes.sh <clip.mp4> <out prefix> <second> …
CLIP=$1
OUT=$2
shift 2
for t in "$@"; do
	ffmpeg -loglevel error -y -ss "$t" -i "$CLIP" -frames:v 1 -vf "scale=2000:-2" -q:v 3 "${OUT}_${t}s.jpg"
	echo "${OUT}_${t}s.jpg"
done
ffprobe -v error -show_entries format=duration -of csv=p=0 "$CLIP"
