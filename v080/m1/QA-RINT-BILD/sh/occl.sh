#!/bin/bash
# occl.sh <tag> <root> <positions> : occlusion probe (qa_occl.gd) under the heavy lock; output $S/occl/<tag>.log + pictures
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
TAG=$1; ROOT=$2; POS=$3
mkdir -p $S/occl/$TAG
[ -e $S/occl/$TAG.done ] && exit 0
exec 9>$S/heavy.lock
flock 9
export XDG_DATA_HOME=$S/xdg/occl_$TAG; rm -rf $XDG_DATA_HOME; mkdir -p $XDG_DATA_HOME
cp $S/sh/qa_occl.gd $ROOT/qa_occl.gd
cd $ROOT
t0=$SECONDS
nice -n 10 timeout 3600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s res://qa_occl.gd -- --graphics=modern --gfx-sync --gfx-preset=high "--pos=$POS" --save=$S/occl/$TAG > $S/occl/$TAG.log 2>&1
echo "exit=$? $((SECONDS-t0))s" >> $S/occl/$TAG.log
touch $S/occl/$TAG.done
flock -u 9
