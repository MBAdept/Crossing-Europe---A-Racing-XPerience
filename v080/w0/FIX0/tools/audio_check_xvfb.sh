#!/usr/bin/env bash
# Fix-wave helper (not part of the repository): check_modern_audio.gd under Xvfb.
# Usage: audio_check_xvfb.sh <project> <log> <xdg dir> <free|fixed> [args after --]
set -uo pipefail
PROJ=$1; LOG=$2; X=$3; MODE=$4
shift 4
FIXED=()
[ "$MODE" = fixed ] && FIXED=(--fixed-fps 60)
rm -rf "$X"; mkdir -p "$X"
cd "$PROJ"
t0=$SECONDS
XDG_DATA_HOME="$X" nice -n 10 timeout 400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 "${FIXED[@]+"${FIXED[@]}"}" -s res://tests/unit/audio_modern/check_modern_audio.gd -- --graphics=arcade "$@" > "$LOG" 2>&1
echo "== $(basename "$LOG" .log) ($MODE $*): Exit $?, $((SECONDS - t0)) s, CHECK-Zeilen $(grep -c '^CHECK ' "$LOG"), FEHLER $(grep -c '^CHECK .*FEHLER' "$LOG"), Skriptfehler $(grep -c 'SCRIPT ERROR' "$LOG")"
grep -E "^CHECK race|^CHECKS" "$LOG" | cut -c1-230
