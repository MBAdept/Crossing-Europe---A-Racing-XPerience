#!/usr/bin/env bash
# UI1 scratch helper: screenshots of the menus under Xvfb with an own XDG_DATA_HOME.
#   shot.sh <worktree> <out_prefix> <xdg name> [game args…]     env: SCREEN=1280x720, FPS=60, TIMEOUT=240
# The scene is res://scenes/main.tscn unless --scene=<path> is given.
set -uo pipefail
WT=$1; OUT=$2; XDG=$3; shift 3
BASE=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/UI1
export XDG_DATA_HOME="$BASE/xdg/$XDG"
export MESA_SHADER_CACHE_DIR="$BASE/xdg/mesa_cache"
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$(dirname "$OUT")"
SCREEN=${SCREEN:-1280x720}
FPS=${FPS:-60}
SCENE="res://scenes/main.tscn"
ARGS=()
for a in "$@"; do
	case "$a" in
		--scene=*) SCENE="${a#--scene=}" ;;
		*) ARGS+=("$a") ;;
	esac
done
cd "$WT"
nice -n 10 timeout "${TIMEOUT:-240}" xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution "$SCREEN" --fixed-fps "$FPS" "$SCENE" -- --screenshot="$OUT" "${ARGS[@]}" 2>&1 \
	| grep -vE "^ALSA|^\s*$|V-Sync|set_use_vsync|^Godot Engine|^OpenGL API" | awk '!seen[$0]++' | head -60
ls -1 "$OUT"_*.png 2>/dev/null || echo "keine Screenshots erzeugt"
