#!/usr/bin/env bash
# SPIKE: review frames of the curated attract scenes (config attract.scenes) for one graphics mode, as fast as
# software OpenGL allows: fixed 60 fps simulation, the picture rendered only for the last frames before each shot
# (--shot-fast). Usage: review_sheet.sh <project dir> <out dir> <arcade|modern> [shot seconds, default 4,12]
set -uo pipefail
PROJ="$1"; OUT="$2"; MODE="$3"; TIMES="${4:-4,12}"
mkdir -p "$OUT"
cd "$PROJ"
python3 - "$PROJ" <<'PY' > "$OUT/scenes.txt"
import json, sys
c = json.load(open(sys.argv[1] + '/config/game_config.json'))
for s in c['attract']['scenes']:
    print(s['id'], s['stage'], s['from'], s['km'], s['hour'], s['weather'], s['vehicle'], s.get('seed', 1), s['speed_kmh'])
PY
T0=$(date +%s.%N)
while read -r id stage from km hour weather vehicle seed speed; do
	t0=$(date +%s.%N)
	timeout 170 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- --screenshot="$OUT/${MODE}_${id}" \
		--stage="$stage" --from="$from" --start-km="$km" --hour="$hour" --weather="$weather" --vehicle="$vehicle" \
		--seed="$seed" --autopilot --no-countdown --shot-times="$TIMES" --shot-fast --graphics="$MODE" 2>&1 \
		| grep -E "SCRIPT ERROR|^ERROR" | head -3
	printf "%-10s %5.1f s\n" "$id" "$(echo "$(date +%s.%N) - $t0" | bc)"
done < "$OUT/scenes.txt"
printf "total %5.1f s\n" "$(echo "$(date +%s.%N) - $T0" | bc)"
(cd "$OUT" && md5sum ${MODE}_*.png > "${MODE}.md5")
