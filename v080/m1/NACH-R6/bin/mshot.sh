#!/usr/bin/env bash
# NACH-R6: one Modern-only run of the race scene with the arguments of tools/ab_shot.sh (same command line as its
# run modern), for the base pictures (c8b18d1 builders swapped into the worktree).
#   mshot.sh <out_prefix> <race args…>      pictures <out_prefix>_modern_NN.png, log <out_prefix>_modern.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4
OUT=$1
shift
cd "$W" || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$MESA_SHADER_CACHE_DIR" "$(dirname "$OUT")"
X=$(mktemp -d "$S/xdg_m.XXXXXX")
rm -f "${OUT}"_modern_[0-9][0-9].png
XDG_DATA_HOME="$X" nice -n 10 timeout 2400 xvfb-run -a -s "-screen 0 ${SCREEN:-1280x720}x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution "${SCREEN:-1280x720}" --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=${OUT}_modern" "$@" "--graphics=modern" --gfx-sync ${GFX_ARGS:---gfx-preset=high} >"${OUT}_modern.log" 2>&1
code=$?
rm -rf "$X"
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR" "${OUT}_modern.log" | head -3
exit $code
