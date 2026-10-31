#!/usr/bin/env bash
# Renders screenshots of a stage under a virtual X server (software OpenGL).
# Usage: tools/screenshot.sh <out_prefix> [game args...]
#   tools/screenshot.sh /tmp/shot --stage=dev_testetappe --start-km=48 --hour=21 --autopilot --shot-times=2,4
# Without --scene the race scene is started directly; --scene=res://scenes/main.tscn starts the menus.
# SCREEN=1280x800 renders on a screen of that size with a window filling it (Steam Deck: 16:10, the
# 16:9 picture gets black bars); the screenshots then show the whole window including the bars.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
OUT="$1"; shift
SCREEN=${SCREEN:-1280x720}
SCENE="res://scenes/race/race.tscn"
ARGS=()
for a in "$@"; do
	case "$a" in
		--scene=*) SCENE="${a#--scene=}" ;;
		*) ARGS+=("$a") ;;
	esac
done
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 180 xvfb-run -a -s "-screen 0 ${SCREEN}x24" "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" "$SCENE" -- --screenshot="$OUT" "${ARGS[@]}" 2>&1 | grep -vE "^ALSA|^\s*$|V-Sync|set_use_vsync" | awk '!seen[$0]++' | head -80 || true
ls -1 "$OUT"_*.png 2>/dev/null || echo "keine Screenshots erzeugt"
