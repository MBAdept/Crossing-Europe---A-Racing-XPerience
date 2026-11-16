#!/usr/bin/env bash
# FIX-WASSER: the Modern half of tools/ab_shot.sh (same command line, same order of the arguments) – for the
# "before" pictures, which are drawn with the far_ground.gd of the base set in by before_queue.sh.
#   SCREEN=1280x720 GFX_ARGS="--gfx-preset=high" modern_only.sh <out_prefix> [race scene arguments…]
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
OUT=$1
shift
SCREEN=${SCREEN:-1280x720}
export MESA_SHADER_CACHE_DIR=$S/mesa
X=$(mktemp -d "$S/xdg_mo.XXXXXX")
mkdir -p "$(dirname "$OUT")"
rm -f "${OUT}"_modern_[0-9][0-9].png
t0=$SECONDS
# shellcheck disable=SC2086
XDG_DATA_HOME="$X" nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=${OUT}_modern" "$@" ${GFX_ARGS:-} "--graphics=modern" --gfx-sync >"${OUT}_modern.log" 2>&1
code=$?
rm -rf "$X"
n=$(find "$(dirname "$OUT")" -maxdepth 1 -name "$(basename "$OUT")_modern_[0-9][0-9].png" | wc -l)
echo "    modern $n Bild(er), $((SECONDS - t0)) s, exit $code: $OUT"
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Modus Modern nicht möglich" "${OUT}_modern.log" | head -3
