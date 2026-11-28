#!/usr/bin/env bash
# Records a whole race through the real GameFlow with its sound, frame-exact (Movie Maker): race selection, every
# stage with countdown and autopilot, result screens, route choices, ferries, race result – the sound as it leaves
# the game (after the Master volume), at the menu music and every volume setting of a fresh user folder.
#   tools/audio/record_race.sh <arcade|modern> <out dir> [race id] [vehicle] [dwell s]
#     defaults: kiel_nuernberg, gran_turismo, 6 s on every screen
# Output in <out dir>: race_<profile>.flac (the whole sound, 48 kHz stereo), race_<profile>.log (the run with lines
# "ZEIT <game s> <screen>" – the time axis of the recording) and race_<profile>.mp3 (to listen to).
# The picture is the Arcade renderer at 64×36 (the sound does not read the renderer, contract Rule 4; the Modern
# renderer under llvmpipe would take hours longer). Kiel – Nürnberg: about 35 min of game time, about 2.5 h here.
# Needs xvfb-run and ffmpeg. Environment: GODOT, XDG_DATA_HOME (absolute; otherwise a temporary user folder).
# Package AU-E (docs/audio-modern.md §17).
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
PROFILE=${1:-}
OUT=${2:-}
RACE=${3:-kiel_nuernberg}
VEHICLE=${4:-gran_turismo}
DWELL=${5:-6}
case "$PROFILE" in
arcade | modern) ;;
*)
	sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
	;;
esac
[ -n "$OUT" ] || { echo "Ausgabeordner fehlt"; exit 2; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
OWN_HOME=""
case "${XDG_DATA_HOME:-}" in
/*) ;;
*)
	OWN_HOME=$(mktemp -d "${TMPDIR:-/tmp}/ce_record_race.XXXXXX")
	export XDG_DATA_HOME="$OWN_HOME"
	;;
esac
AVI="$OUT/race_$PROFILE.avi"
trap 'rm -f "$AVI"; [ -n "$OWN_HOME" ] && rm -rf "$OWN_HOME"' EXIT
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
nice -n 10 xvfb-run -a -s "-screen 0 640x360x24" "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 64x36 --fixed-fps 60 --write-movie "$AVI" -s res://tests/race/run_race.gd -- \
	--race="$RACE" --vehicle="$VEHICLE" --autopilot --timescale=1 --dwell="$DWELL" --timeline --max-seconds=30000 \
	--graphics=arcade --sound="$PROFILE" --audio-sync >"$OUT/race_$PROFILE.log" 2>&1
code=$?
grep -E "^(RENNEN|RACE-RUN|RENNERGEBNIS|FEHLER)" "$OUT/race_$PROFILE.log"
ffmpeg -v error -y -i "$AVI" -vn -c:a flac "$OUT/race_$PROFILE.flac" &&
	ffmpeg -v error -y -i "$OUT/race_$PROFILE.flac" -c:a libmp3lame -q:a 2 "$OUT/race_$PROFILE.mp3"
echo "==> $OUT/race_$PROFILE.flac (Exit $code)"
exit $code
