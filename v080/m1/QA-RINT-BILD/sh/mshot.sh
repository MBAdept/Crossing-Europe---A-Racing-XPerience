#!/bin/bash
# mshot.sh <root> <out_prefix> [race args...] : one Modern run (like tools/ab_shot.sh's modern half), GFX_ARGS added
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
ROOT=$1; OUT=$2; shift 2
SCREEN=${SCREEN:-1280x720}
X=$(mktemp -d $S/xdg/m.XXXXXX)
cd $ROOT
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 timeout ${AB_TIMEOUT:-900} xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
  --rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
  "--screenshot=${OUT}_modern" "$@" ${GFX_ARGS:-} --graphics=modern --gfx-sync > ${OUT}_modern.log 2>&1
echo "exit=$? $((SECONDS-t0))s" >> ${OUT}_modern.log
rm -rf $X
grep -E "SCRIPT ERROR|SHADER ERROR|Modus Modern nicht" ${OUT}_modern.log | head -3
ls ${OUT}_modern_*.png 2>/dev/null | wc -l
