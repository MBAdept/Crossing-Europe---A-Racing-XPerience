#!/usr/bin/env bash
# Contact sheet of the real-time models of the mode "Modern" (docs/modelle.md), rendered with the game's
# materials under a virtual X server (software OpenGL).
# Usage: tools/models_contact_sheet.sh <out.png> [--only=<glob>] [--night] [--tile=480x320] [--cols=4]
#                                      [--lods=lod0,show] [--showroom]
#   tools/models_contact_sheet.sh /tmp/day.png
#   tools/models_contact_sheet.sh /tmp/night.png --night --only="traffic/*"
# --night: ce_night = 1 and, for vehicles, one tile per lamp channel. --showroom: the `show` level of the
# player cars from the camera of the Cycles showroom sprites.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
if [ $# -lt 1 ]; then
	sed -n '2,10p' "$0"
	exit 1
fi
OUT="$1"; shift
case "$OUT" in
	/*) ;;
	*) OUT="$PWD/$OUT" ;;
esac
mkdir -p "$(dirname "$OUT")"
# every run of the game or a tool gets its own user data folder (never the player's)
if [ -z "${XDG_DATA_HOME:-}" ]; then
	XDG_DATA_HOME="$(mktemp -d)"
	export XDG_DATA_HOME
fi
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tools/models/contact_sheet.gd -- "--out=$OUT" "$@" 2>&1 \
	| grep -vE "^ALSA|^\s*$|V-Sync|set_use_vsync|^Godot Engine|^OpenGL API" | awk '!seen[$0]++' | head -60 || true
if [ -f "$OUT" ]; then
	echo "$OUT"
else
	echo "kein Kontaktbogen erzeugt"
	exit 1
fi
