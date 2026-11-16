#!/bin/bash
# usage: drive_all.sh <scenario> <outdir-name> [profile] [bankdir]  -> offline renders for all five cars
# env: CARS="kompakt ..." (default all), EXTRA="--layers ..." (more args of e3render.gd)
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
SC=${1:-drive}
OUT=$W/${2:-r1}
PROF=${3:-modern}
BD=${4:-$W/b2/assets/audio/modern/engines}
export XDG_DATA_HOME=$W/../xdg
mkdir -p "$OUT"
for car in ${CARS:-kompakt kombi limousine sportwagen gran_turismo}; do
	godot --headless --path "$R" -s "$W/e3render.gd" -- --car=$car --profile=$PROF --scenario=$SC --bank-dir="$BD" --assets-dir="$W/b2/assets/audio/modern" $EXTRA --out="$OUT/${car}_${PROF}_${SC}.wav" 2>&1 | grep -E 'ERROR|FEHLER|e3render|Hinweis' | sed -e 's#/tmp/claude-0/[^ ]*/work/##g' | cut -c1-200
done
