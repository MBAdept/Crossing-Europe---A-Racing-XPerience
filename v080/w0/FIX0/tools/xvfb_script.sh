#!/usr/bin/env bash
# Integration helper (not part of the repository): one script of the project under Xvfb with software OpenGL and the
# Dummy audio driver, with its own empty XDG_DATA_HOME.
# Usage: xvfb_script.sh <project dir> <log file> <xdg dir> <script (res:// relative)> [args after --]
set -uo pipefail
PROJ=$1
LOG=$2
case "${3:-}" in /*) ;; *) echo "xvfb_script.sh: <xdg dir> muss ein absoluter Pfad sein (bekam: ${3:-nichts})"; exit 2 ;; esac
case "$LOG" in /*) ;; *) echo "xvfb_script.sh: <log file> muss ein absoluter Pfad sein"; exit 2 ;; esac
export XDG_DATA_HOME=$3
SCRIPT=$4
shift 4
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME" "$(dirname "$LOG")"
cd "$PROJ"
t0=$SECONDS
nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --fixed-fps 60 -s "res://$SCRIPT" -- "$@" > "$LOG" 2>&1
code=$?
echo "== $SCRIPT $*: Exit $code, $((SECONDS - t0)) s, CHECK-Zeilen $(grep -c '^CHECK ' "$LOG"), FEHLER $(grep -c '^CHECK.*FEHLER' "$LOG"), Skriptfehler $(grep -c 'SCRIPT ERROR' "$LOG"), ERROR-Zeilen $(grep -c '^ERROR' "$LOG")"
grep -E "^(RENDER-)?CHECK" "$LOG" | cut -c1-700
