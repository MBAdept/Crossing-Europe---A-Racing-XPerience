#!/bin/bash
# mshot.sh <base|head> <name> <POS> <preset> [extra args...] – Modern only, pictures shots/<which>/<name>_modern_NN.png
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WHICH=$1; NAME=$2; POS=$3; PRESET=$4; shift 4
if [ "$WHICH" = base ]; then WT=$S/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7; fi
ARGS=$("$S/sh/pos.sh" "$POS") || exit 2
OUT=$S/shots/$WHICH/$NAME
mkdir -p "$S/xdg/${WHICH}_$NAME"
rm -f "${OUT}"_modern_[0-9][0-9].png
export MESA_SHADER_CACHE_DIR=$S/mesa_$WHICH
SCREEN=${SCREEN:-1280x720}
cd "$WT" || exit 2
t0=$SECONDS
# shellcheck disable=SC2086
XDG_DATA_HOME="$S/xdg/${WHICH}_$NAME" nice -n ${NICE:-10} timeout ${TO:-900} xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
  "--screenshot=${OUT}_modern" $ARGS "$@" --gfx-preset=$PRESET --graphics=modern --gfx-sync > "${OUT}_modern.log" 2>&1
code=$?
echo "mshot $WHICH $NAME exit=$code $((SECONDS-t0))s"
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Modus Modern nicht" "${OUT}_modern.log" | head -5
ls "${OUT}"_modern_*.png 2>/dev/null
