#!/usr/bin/env bash
# Integration helper (not part of the repository): Rule 4 of the build contract on the merged tree – the Arcade
# picture must not depend on the sound profile. Renders runs of the golden frame list exactly as tools/golden.sh
# check does, but with "--sound=modern" added, and compares the PNGs with the hash list of v0.7.0.
# Usage: sound_combo_frames.sh <project dir> <out dir> <id filter>...
set -uo pipefail
PROJ=$1
OUT=$2
shift 2
mkdir -p "$OUT"
export XDG_DATA_HOME="$OUT/xdg" MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$OUT/mesa}"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$PROJ"
LIST=tests/golden/arcade_v070.md5
same=0
total=0
grep -vE '^\s*(#|$)' tests/golden/arcade_frames.txt | while IFS='|' read -r id times args; do
	id=$(echo "$id" | tr -d ' \t')
	times=$(echo "$times" | tr -d ' \t')
	want=0
	for f in "$@"; do [[ "$id" == *"$f"* ]] && want=1; done
	[ $want -eq 1 ] || continue
	t0=$SECONDS
	# shellcheck disable=SC2086
	nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- \
		--screenshot="$OUT/$id" --shot-times="$times" $args --graphics=arcade --shot-fast --gfx-sync --sound=modern --perf >"$OUT/$id.log" 2>&1
	code=$?
	n=$(echo "$times" | tr ',' '\n' | grep -c .)
	for ((i = 0; i < n; i++)); do
		f=$(printf '%s_%02d.png' "$id" "$i")
		have=$(md5sum < "$OUT/$f" 2>/dev/null | cut -d' ' -f1)
		ref=$(awk -v f="$f" '$2 == f { print $1 }' "$LIST")
		echo "  $f: $([ -n "$have" ] && [ "$have" = "$ref" ] && echo identisch || echo ANDERS) ($have)"
	done
	echo "  $id: Exit $code, $((SECONDS - t0)) s, Skriptfehler $(grep -c 'SCRIPT ERROR' "$OUT/$id.log"), ERROR-Zeilen $(grep -c '^ERROR' "$OUT/$id.log"), $(grep -m1 -o "AUDIO_PERF {\"profile\":\"[a-z]*\"" "$OUT/$id.log")"
done
