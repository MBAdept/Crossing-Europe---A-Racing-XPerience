#!/usr/bin/env bash
# Integration helper (not part of the repository): run_stage.gd on the given stages in every combination of
# graphics mode and sound profile, one run after the other. Usage: stage_runs.sh <project dir> <out dir> <stage>...
# Every run gets its own empty XDG_DATA_HOME below <out dir>.
set -uo pipefail
PROJ=$1
OUT=$2
shift 2
mkdir -p "$OUT"
cd "$PROJ"
for st in "$@"; do
	for combo in arcade:arcade modern:arcade arcade:modern modern:modern; do
		gfx=${combo%%:*}
		snd=${combo##*:}
		id="${st}_g-${gfx}_s-${snd}"
		home="$OUT/xdg_$id"
		rm -rf "$home"
		mkdir -p "$home"
		t0=$SECONDS
		XDG_DATA_HOME="$home" nice -n 10 timeout 1500 godot --headless --path . -s res://tests/race/run_stage.gd -- \
			--stage="$st" --graphics="$gfx" --sound="$snd" > "$OUT/run_$id.log" 2>&1
		code=$?
		echo "$id: Exit $code, $((SECONDS - t0)) s, Skriptfehler $(grep -c 'SCRIPT ERROR' "$OUT/run_$id.log"), ERROR-Zeilen $(grep -c '^ERROR' "$OUT/run_$id.log"), Marker übrig: $(find "$home" -name 'modern_start.lock' | wc -l)"
	done
done
