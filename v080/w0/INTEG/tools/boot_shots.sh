#!/usr/bin/env bash
# Integration helper (not part of the repository): the whole game (main scene) on the merged tree under Xvfb –
# title screen and an attract demo – once per graphics mode, with the Modern sound profile in the second run.
# Then the contact sheets of the model pipeline by day and at night.
# Usage: boot_shots.sh <project dir> <out dir>
set -uo pipefail
PROJ=$1
OUT=$2
mkdir -p "$OUT"
cd "$PROJ"
boot() { # <name> <game args…>
	local name=$1
	shift
	export XDG_DATA_HOME="$OUT/xdg_$name"
	rm -rf "$XDG_DATA_HOME"
	mkdir -p "$XDG_DATA_HOME"
	local t0=$SECONDS
	nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 res://scenes/main.tscn -- --screenshot="$OUT/$name" --shot-times=2,12 \
		--attract-after=4 --attract-scene=3 "$@" > "$OUT/$name.log" 2>&1
	echo "== $name: Exit $?, $((SECONDS - t0)) s, Skriptfehler $(grep -c 'SCRIPT ERROR' "$OUT/$name.log"), ERROR-Zeilen $(grep -c '^ERROR' "$OUT/$name.log"), Bilder $(ls "$OUT/$name"_*.png 2>/dev/null | wc -l), Marker übrig $(find "$XDG_DATA_HOME" -name modern_start.lock | wc -l), Klang: $(grep -c 'ModernAudio: Profil' "$OUT/$name.log") × Modern gestartet"
}
boot spiel_arcade --graphics=arcade
boot spiel_modern --graphics=modern --sound=modern --gfx-sync
export XDG_DATA_HOME="$OUT/xdg_sheet"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME"
for v in tag nacht; do
	t0=$SECONDS
	if [ $v = nacht ]; then
		nice -n 10 tools/models_contact_sheet.sh "$OUT/kontaktbogen_$v.png" --night > "$OUT/kontaktbogen_$v.log" 2>&1
	else
		nice -n 10 tools/models_contact_sheet.sh "$OUT/kontaktbogen_$v.png" > "$OUT/kontaktbogen_$v.log" 2>&1
	fi
	echo "== kontaktbogen_$v: Exit $?, $((SECONDS - t0)) s, Skriptfehler $(grep -c 'SCRIPT ERROR' "$OUT/kontaktbogen_$v.log"), $(ls -la "$OUT/kontaktbogen_$v.png" 2>/dev/null | awk '{print $5}') Bytes"
done
