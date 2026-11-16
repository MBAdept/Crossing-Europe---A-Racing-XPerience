#!/usr/bin/env bash
# Integration helper (not part of the repository): smoke run of a Linux export under Xvfb – the same two runs as
# wine_smoke.sh (started through the game's own start with "-- --stage=…").
# Usage: linux_smoke.sh <executable> <out dir> <tag> <xdg dir> [extra game args…]
set -uo pipefail
EXE=$1
OUT=$2
TAG=$3
case "${4:-}" in /*) ;; *) echo "linux_smoke.sh: <xdg dir> muss ein absoluter Pfad sein"; exit 2 ;; esac
export XDG_DATA_HOME=$4
shift 4
EXTRA=("$@")
mkdir -p "$OUT" "$XDG_DATA_HOME"
run() { # id times args...
	local id=$1 times=$2
	shift 2
	local t0=$SECONDS
	nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" "$EXE" --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 -- --screenshot="$OUT/${TAG}_$id" --shot-times="$times" \
		"$@" "${EXTRA[@]+"${EXTRA[@]}"}" --shot-fast > "$OUT/${TAG}_$id.log" 2>&1
	echo "  $TAG $id: Exit $?, $((SECONDS - t0)) s, $(grep -c 'SCRIPT ERROR' "$OUT/${TAG}_$id.log") Skriptfehler, $(grep -c '^ERROR' "$OUT/${TAG}_$id.log") ERROR-Zeilen, $(grep -m1 -o 'OpenGL API.*' "$OUT/${TAG}_$id.log" | cut -c1-90)"
}
run race_s1 2.2 --stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup
run regen 4,12 --stage=leipzig_berlin --from=leipzig --start-km=159.0 --hour=23.0 --weather=rain --vehicle=limousine --seed=3 --autopilot --autopilot-target=215 --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=170
(cd "$OUT" && md5sum "${TAG}"_*.png)
