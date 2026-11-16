#!/usr/bin/env bash
# usage: run_jobs.sh <jobs.json> <outdir>
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1-KRITIK
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa
mkdir -p "$2" "$MESA_SHADER_CACHE_DIR"
cd $S/wt
timeout 1500 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  -s res://tools/kritik/kritik_render.gd -- "--jobs=$1" "--outdir=$2" 2>&1 | grep -vE "^ALSA|^\s*$|V-Sync|set_use_vsync|^Godot Engine|^OpenGL API" | awk '!seen[$0]++' | head -80
