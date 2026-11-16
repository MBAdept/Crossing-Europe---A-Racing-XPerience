#!/bin/bash
CO=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/co_zs1
OUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE
cd $CO
for cfg in "1280 800 traffic/wagon_white behind 40" "1280 800 traffic/hatch_white ahead 40" "1920 1080 traffic/wagon_white ahead 40" "1920 1080 traffic/hatch_white behind 40" "1280 800 traffic/wagon_white side 36"; do
  set -- $cfg
  XDG_DATA_HOME=$OUT/xdg MESA_SHADER_CACHE_DIR=$OUT/mesa timeout 900 nice -n 10 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://flk_swap.gd -- --w=$1 --h=$2 --set=$3 --sun=$4 --dist=$5 2>&1 | grep -E "^FLK|SCRIPT ERROR|Parse Error" 
done
