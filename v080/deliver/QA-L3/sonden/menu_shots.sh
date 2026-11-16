#!/usr/bin/env bash
# QA lens 3: the menu screens (sample data) as pictures, tag v0.7.0 against the integrated tree.
#   menu_shots.sh <tree> <out dir> <xdg> [extra game args…]
set -uo pipefail
TREE=$1; OUT=$2; XDG=$3; shift 3
mkdir -p "$OUT" "$XDG"
for s in title race_select vehicle start_time stage_select route_choice stage_screen result race_result leaderboards options ferry; do
	XDG_DATA_HOME=$XDG nice -n 10 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$TREE" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/main.tscn -- --screen=$s --screenshot="$OUT/$s" \
		--shot-times=1.5,3 "$@" > "$OUT/$s.log" 2>&1
	echo "$s exit $? $(ls "$OUT"/${s}_*.png 2>/dev/null | wc -l) Bilder"
done
(cd "$OUT" && md5sum *.png > md5.txt)
