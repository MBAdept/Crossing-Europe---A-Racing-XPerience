#!/usr/bin/env bash
# Scratch (wave-0 integration, not part of the repository): pictures of the geometry kernel behind the real
# renderer seam (stub renderer + kernel_probe_renderer.gd) and of Arcade at the same positions and times.
# Usage: shot_runs.sh <project dir> <out dir>
set -uo pipefail
PROJ=$1
OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
export XDG_DATA_HOME="$OUT/xdg" MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$OUT/mesa}"
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$PROJ"
shot() { # <id> <mode> <times> <args…>
	local id=$1 mode=$2 times=$3
	shift 3
	local t0=$SECONDS
	nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 -s "$HERE/shot_probe.gd" -- "--probe=$HERE/kernel_probe_renderer.gd" \
		--screenshot="$OUT/${id}_$mode" --shot-times="$times" "$@" --graphics="$mode" --gfx-sync > "$OUT/${id}_$mode.log" 2>&1
	echo "  ${id}_$mode: Exit $?, $((SECONDS - t0)) s, Skriptfehler $(grep -c 'SCRIPT ERROR' "$OUT/${id}_$mode.log"), ERROR-Zeilen $(grep -c '^ERROR' "$OUT/${id}_$mode.log"), Bilder $(ls "$OUT/${id}_$mode"_*.png 2>/dev/null | wc -l)"
}
for mode in arcade modern; do
	shot s1 $mode 6 --stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup
	shot t1 $mode 6 --stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --weather=normal --vehicle=kombi --seed=12 --autopilot --traffic-warmup
	shot t4 $mode 6 --stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=12 --weather=normal --vehicle=kompakt --seed=4 --autopilot --traffic-warmup
done
