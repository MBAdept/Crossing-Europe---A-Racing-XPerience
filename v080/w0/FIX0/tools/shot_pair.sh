#!/usr/bin/env bash
# Fix-wave helper (not part of the repository): one screenshot run of the game under Xvfb.
# Usage: shot_pair.sh <project dir> <out prefix> <standalone|gameflow> <graphics> <times> [args…]
set -uo pipefail
PROJ=$1; OUT=$2; HOW=$3; GFX=$4; TIMES=$5
shift 5
SCENE=()
[ "$HOW" = standalone ] && SCENE=(res://scenes/race/race.tscn)
nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$PROJ" --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --fixed-fps 60 "${SCENE[@]+"${SCENE[@]}"}" -- --screenshot="$OUT" --shot-times="$TIMES" "$@" --graphics="$GFX" > "$OUT.log" 2>&1
echo "$(basename "$OUT"): Exit $?, Skriptfehler $(grep -c 'SCRIPT ERROR' "$OUT.log")"
