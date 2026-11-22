#!/bin/bash
# frames.sh <clip.mp4> <outdir> <t1> [t2 ...] : single frames of an A/B clip (both halves) as JPG
CLIP=$1; OUT=$2; shift 2
mkdir -p $OUT
B=$(basename $CLIP .mp4)
for T in "$@"; do
  nice -n 10 ffmpeg -loglevel error -y -ss $T -i $CLIP -frames:v 1 -q:v 3 $OUT/${B}_t${T}.jpg
  echo $OUT/${B}_t${T}.jpg
done
