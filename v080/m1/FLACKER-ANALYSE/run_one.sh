#!/bin/bash
# usage: run_one.sh preset from km hour sim scale
CO=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/co_zs1
OUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE
cd $CO
LOG=$OUT/refusal_$1_$2_$3_$4_w${7:-0}.log
XDG_DATA_HOME=$OUT/xdg MESA_SHADER_CACHE_DIR=$OUT/mesa timeout 1800 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -s res://flk_refusal_run.gd -- --graphics=modern --gfx-preset=$1 --flk-from=$2 --flk-km=$3 --flk-hour=$4 --flk-sim=$5 --flk-scale=$6 --flk-warm=${7:-0} --flk-probe-every=${8:-30} > $LOG 2>&1
echo "exit $? $(date +%T)" >> $LOG
grep "^FLK" $LOG
