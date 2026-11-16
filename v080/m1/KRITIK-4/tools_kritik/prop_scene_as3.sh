#!/usr/bin/env bash
# Review scene of the prop models of the mode "Modern" (docs/modelle.md sections 14 and 15): the models beside a road
# through the game camera, by distance (lod0 / lod1 / impostor as the props builder picks them), the levels side
# by side, or a whole roadside. Rendered with the game's materials under a virtual X server (software OpenGL).
# Usage: tools/models/prop_scene.sh <out.png> --models=<id>,<id>... [--mode=dist|lods|road|clip] [--dist=15,40,100,250]
#                                   [--x=9] [--night] [--zoom=4] [--tile=360x300] [--every=30] [--sun=x,y,z]
#                                   [--look=race [--hour=12] [--weather=normal] [--preset=medium]] [--sprite]
#   tools/models/prop_scene.sh /tmp/trees.png --models=props/tree_oak,props/tree_oak_b
#   tools/models/prop_scene.sh /tmp/road.png --mode=road --models=props/tree_oak,props/tree_birch,props/bush_round
#   tools/models/prop_scene.sh /tmp/stufen.png --mode=lods --look=race --hour=19.5 --sprite --models=props/tree_beech
#   tools/models/prop_scene.sh /tmp/clip.png --mode=clip --look=race --models=props/tree_poplar   (-> /tmp/clip_NNN.png)
# Options and measurements: see the header of tools/models/prop_scene.gd.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
if [ $# -lt 2 ]; then
	sed -n '2,12p' "$0"
	exit 1
fi
OUT="$1"; shift
case "$OUT" in
	/*) ;;
	*) OUT="$PWD/$OUT" ;;
esac
mkdir -p "$(dirname "$OUT")"
# every run gets its own user data folder (never the player's); only an absolute XDG_DATA_HOME counts
case "${XDG_DATA_HOME:-}" in
/*) ;;
*)
	XDG_DATA_HOME="$(mktemp -d "${TMPDIR:-/tmp}/ce_prop_scene.XXXXXX")"
	XDG_DATA_HOME="$(cd "$XDG_DATA_HOME" && pwd)"
	export XDG_DATA_HOME
	;;
esac
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tools/models/prop_scene.gd -- "--out=$OUT" "$@" 2>&1 \
	| grep -E "^(SZENE|STUFEN|UMSCHALT|prop_scene)|ERROR|SCRIPT|Parse Error" | awk '!seen[$0]++' | head -80 || true
FIRST="$OUT"
case " $* " in
*" --mode=clip "*) FIRST="${OUT%.png}_000.png" ;;
esac
if [ -f "$FIRST" ]; then
	echo "$FIRST"
else
	echo "kein Bild erzeugt"
	exit 1
fi
