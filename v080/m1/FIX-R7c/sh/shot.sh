#!/bin/bash
# shot.sh <name> <tag> <preset> <race args...>: one run of the race scene from the FIX-R7c tree
#   -> $S/shots/<name>_<tag>_NN.png (MODE=modern|arcade, SCREEN=WxH)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
NAME=$1
TAG=$2
PRE=$3
shift 3
SCREEN=${SCREEN:-1280x720}
MODE=${MODE:-modern}
OUT=$S/shots/${NAME}_${TAG}
memwait
t0=$SECONDS
x=$S/xdg_shot
rm -rf "$x"
mkdir -p "$x"
EXTRA=("--gfx-preset=$PRE")
[ "$MODE" = "arcade" ] && EXTRA=("--shot-fast")
cd "${TREE:-$WT}" || exit 1
XDG_DATA_HOME=$x nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=$OUT" "$@" "--graphics=$MODE" "${EXTRA[@]}" --gfx-sync > "$OUT.log" 2>&1
code=$?
errs=$(grep -cE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Too many instances|Modus Modern nicht" "$OUT.log")
echo "$(date -u +%H:%M:%S) $NAME $TAG exit=$code err=$errs $((SECONDS - t0)) s" | tee -a "$S/logs/shot.out"
