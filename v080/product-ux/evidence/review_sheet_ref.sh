#!/usr/bin/env bash
# Reference frames from the unmodified v0.7.0 copy (no --shot-fast there: every frame is rendered).
set -uo pipefail
PROJ="$1"; OUT="$2"; TIMES="${3:-4,12}"
mkdir -p "$OUT"
cd "$PROJ"
T0=$(date +%s.%N)
while read -r id stage from km hour weather vehicle seed speed; do
	t0=$(date +%s.%N)
	timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- --screenshot="$OUT/ref_${id}" \
		--stage="$stage" --from="$from" --start-km="$km" --hour="$hour" --weather="$weather" --vehicle="$vehicle" \
		--seed="$seed" --autopilot --no-countdown --shot-times="$TIMES" 2>&1 | grep -E "SCRIPT ERROR|^ERROR" | head -3
	printf "%-10s %5.1f s\n" "$id" "$(echo "$(date +%s.%N) - $t0" | bc)"
done < "$OUT/scenes.txt"
printf "total %5.1f s\n" "$(echo "$(date +%s.%N) - $T0" | bc)"
(cd "$OUT" && md5sum ref_*.png > ref.md5)
