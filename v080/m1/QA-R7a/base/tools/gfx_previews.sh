#!/usr/bin/env bash
# Preview pictures of the graphics modes for the options and the first-start chooser (docs/grafik-modi.md):
# Kiel – Hamburg at noon from the same simulation state, drawn by Arcade and by Modern, without the HUD, written to
# assets/ui/gfx_preview_{arcade,modern}.webp (960 × 540). Rendered under a virtual X server (software OpenGL) with
# whatever Modern renderer the tree contains – run it again whenever the look of Modern changes.
# Usage: tools/gfx_previews.sh [--out=<dir>] [--only=arcade|modern] [--km=2.0] [--seconds=2.5] [--gfx-preset=high]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
# its own user data folder (never the player's); only an absolute XDG_DATA_HOME of the caller counts
case "${XDG_DATA_HOME:-}" in
/*) ;;
*)
	XDG_DATA_HOME="$(mktemp -d "${TMPDIR:-/tmp}/ce_gfx_previews.XXXXXX")"
	XDG_DATA_HOME="$(cd "$XDG_DATA_HOME" && pwd)"
	export XDG_DATA_HOME
	;;
esac
ARGS=("$@")
case " ${ARGS[*]-} " in
*" --gfx-preset="*) ;;
*) ARGS+=("--gfx-preset=high") ;;   # the best picture the mode can show (software OpenGL: "low" by default)
esac
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --fixed-fps 60 -s res://tools/gfx_previews.gd -- --gfx-sync --audio-sync "${ARGS[@]}" 2>&1 \
	| grep -E "^VORSCHAU|ERROR|SCRIPT" | head -20
# the import of the pictures (lossy WebP in the pack, mipmaps for the scaled-down cards)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
