#!/bin/bash
# mshot.sh <name> <POS> <preset> [extra args...] – Modern only (my worktree), pictures <shots>/<name>_modern_NN.png
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5}
NAME=$1; POS=$2; PRESET=$3; shift 3
ARGS=$("$S/sh/pos.sh" "$POS") || exit 2
OUT=${OUTDIR:-$S/shots}/$NAME
mkdir -p "$(dirname "$OUT")" "$S/xdg/$NAME"
rm -f "${OUT}"_modern_[0-9][0-9].png
export MESA_SHADER_CACHE_DIR=$S/mesa
SCREEN=${SCREEN:-1280x720}
cd "$WT" || exit 2
t0=$SECONDS
# shellcheck disable=SC2086
XDG_DATA_HOME="$S/xdg/$NAME" nice -n ${NICE:-10} timeout ${TO:-900} xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
  "--screenshot=${OUT}_modern" $ARGS "$@" --gfx-preset=$PRESET --graphics=modern --gfx-sync > "${OUT}_modern.log" 2>&1
code=$?
echo "mshot $NAME exit=$code $((SECONDS-t0))s"
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Modus Modern nicht" "${OUT}_modern.log" | head -5
ls "${OUT}"_modern_*.png 2>/dev/null
