#!/usr/bin/env bash
# Scratch (not part of the repo): Arcade smoke run of a Windows build under Wine + Xvfb, same frames as two runs of
# tools/golden.sh. Usage: wine_smoke.sh <exe> <out dir> <tag>
set -uo pipefail
EXE=$1
OUT=$2
TAG=$3
W=$(cd "$(dirname "$0")" && pwd)
export WINEPREFIX="$W/wine" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d" LANG=C.UTF-8
mkdir -p "$OUT"
run() { # id times args...
	local id=$1 times=$2
	shift 2
	local t0=$SECONDS
	nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$EXE" --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 -- --screenshot="Z:$OUT/${TAG}_$id" --shot-times="$times" \
		"$@" --graphics=arcade --shot-fast > "$OUT/${TAG}_$id.log" 2>&1
	echo "  $TAG $id: Exit $?, $((SECONDS - t0)) s, $(grep -c 'SCRIPT ERROR' "$OUT/${TAG}_$id.log") Skriptfehler, $(grep -m1 -o 'OpenGL API.*' "$OUT/${TAG}_$id.log" | cut -c1-90)"
}
run race_s1 2.2 --stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup
run regen 4,12 --stage=leipzig_berlin --from=leipzig --start-km=159.0 --hour=23.0 --weather=rain --vehicle=limousine --seed=3 --autopilot --autopilot-target=215 --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=170
(cd "$OUT" && md5sum "${TAG}"_*.png)
