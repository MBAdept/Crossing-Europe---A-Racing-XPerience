#!/usr/bin/env bash
# Usage: shot.sh <out_name> <viewer args...>   (runs the Godot spike viewer under Xvfb, Compatibility/opengl3)
set -euo pipefail
BASE=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/assets3d
export XDG_DATA_HOME=$BASE/xdg XDG_CONFIG_HOME=$BASE/xdgcfg XDG_CACHE_HOME=$BASE/xdgcache
OUT="$1"; shift
SIZE=${SIZE:-1280x720}
cd $BASE/godot_spike
timeout 240 xvfb-run -a -s "-screen 0 ${SIZE}x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution "$SIZE" -- --out="$BASE/shots/$OUT" "$@" 2>&1 | grep -E "SHOT|ERROR|error|WARNING|Parse|SCRIPT" | grep -vE "V-Sync|set_use_vsync|ALSA" | head -30 || true
