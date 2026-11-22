#!/bin/bash
# perf.sh <root> <tag> <name> <mode> <preset|-> [race args...]  (deck -> 1280x800 screen)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
ROOT=$1; TAG=$2; NAME=$3; MODE=$4; PRESET=$5; shift 5
OUTB=$S/perf/${TAG}_${NAME}_${MODE}_${PRESET}
mkdir -p $S/perf
export XDG_DATA_HOME=$S/xdg/perf_${TAG}_${NAME}_${MODE}_${PRESET}; rm -rf $XDG_DATA_HOME; mkdir -p $XDG_DATA_HOME
cp $S/sh/qa_perf.gd $ROOT/qa_perf.gd
cd $ROOT
PA=""; [ "$PRESET" != "-" ] && PA="--gfx-preset=$PRESET"
SCR=${PERF_RES:-640x360}; [ "$PRESET" = deck ] && SCR=${PERF_RES_DECK:-640x400}
t0=$SECONDS
nice -n 10 timeout ${PERF_TIMEOUT:-3000} xvfb-run -a -s "-screen 0 ${SCR}x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution $SCR -s res://qa_perf.gd -- --graphics=$MODE $PA --out=$OUTB.json "$@" > $OUTB.log 2>&1
echo "exit=$? $((SECONDS-t0))s" >> $OUTB.log
tail -1 $OUTB.log
