#!/bin/bash
# R7D: the fuel stop at 21:00 (check_structures_licht "tankstelle") with saved pictures, head and base – tank.sh <head|base> [tag]
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
t=$1; tag=${2:-$1}
d=$W; [ "$t" = base ] && d=$S/base
O=$S/shots/tank/$tag; rm -rf $O; mkdir -p $O
mkdir -p $S/xdg/tank_$t; export XDG_DATA_HOME=$S/xdg/tank_$t
cd $d
t0=$SECONDS
timeout 900 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --fixed-fps 60 -s res://tests/race3d/render/check_structures_licht.gd -- --graphics=modern --gfx-sync \
	--audio-sync --only=tankstelle --save=$O > $O/run.log 2>&1
echo "$(date +%T) tank $tag exit=$? $((SECONDS - t0)) s: $(grep -E '^RENDER-CHECK tankstelle' $O/run.log | cut -c1-400)"
