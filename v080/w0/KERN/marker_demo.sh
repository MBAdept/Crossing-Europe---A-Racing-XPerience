#!/usr/bin/env bash
# Scratch demonstration (not part of the repo): the crash-guard marker over real process starts.
# Usage: marker_demo.sh <project dir> <empty scratch dir>
set -uo pipefail
PROJ=$1
X=$2
export XDG_DATA_HOME="$X"
U="$X/godot/app_userdata/Crossing Europe – A Racing Xperience"
mkdir -p "$U"
rm -f "$U/modern_start.lock"
printf '{"settings_version": 3, "graphics_mode": "modern"}\n' > "$U/settings.json"
ARGS="--stage=dev_testetappe --start-km=129.2 --start-speed=150 --autopilot --no-countdown --quit-at-finish"
PID=0
run() { # name: starts the race scene in the background of THIS shell, log in <name>.log
	godot --headless --path "$PROJ" res://scenes/race/race.tscn -- $ARGS > "$X/$1.log" 2>&1 &
	PID=$!
}
gfx_of() { grep -m1 '^ERGEBNIS' "$X/$1.log" | sed 's/.*"gfx":"\([a-z]*\)".*/\1/'; }
marker() { [ -f "$U/modern_start.lock" ] && echo "$1" || echo "$2"; }

echo "1) gespeicherte Wahl 'modern', kein --graphics: normaler Lauf"
run a
SEEN=nein
for i in $(seq 1 60); do
	[ -f "$U/modern_start.lock" ] && { SEEN=ja; break; }
	sleep 0.05
done
echo "   Marker während des Laufs gesehen: $SEEN ($(cat "$U/modern_start.lock" 2>/dev/null))"
wait "$PID"
echo "   Exit $?, gfx im Ergebnis: $(gfx_of a), Marker nach dem Lauf: $(marker 'NOCH DA' entfernt)"

echo "2) Lauf wird abgeschossen, sobald der Marker geschrieben ist (kill -9 = Absturz im Modus Modern)"
run b
for i in $(seq 1 100); do
	[ -f "$U/modern_start.lock" ] && break
	sleep 0.05
done
kill -9 "$PID" 2>/dev/null
wait "$PID" 2>/dev/null
echo "   Marker nach dem Absturz: $(marker bleibt FEHLT)"

echo "3) nächster Start, gleiche Einstellungen"
run c
wait "$PID"
echo "   Exit $?, gfx im Ergebnis: $(gfx_of c) (Wahl in settings.json: $(grep -o '"graphics_mode": *"[a-z]*"' "$U/settings.json")), Marker: $(marker 'bleibt bis zur Antwort' entfernt)"

echo "4) mit --graphics=modern trotz Marker (die Kommandozeile gewinnt)"
godot --headless --path "$PROJ" res://scenes/race/race.tscn -- $ARGS --graphics=modern > "$X/d.log" 2>&1
echo "   Exit $?, gfx im Ergebnis: $(gfx_of d), Marker nach 2 s Modern: $(marker 'NOCH DA' entfernt)"

echo "5) danach wieder ohne Argument"
run e
wait "$PID"
echo "   Exit $?, gfx im Ergebnis: $(gfx_of e), Marker: $(marker 'NOCH DA' 'keiner')"
echo "Skriptfehler in den Protokollen: $(cat "$X"/*.log | grep -c 'SCRIPT ERROR')"
