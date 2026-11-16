#!/usr/bin/env bash
# AS2a: the AS1-KRITIK review renderer (scratch copy) on this worktree.  usage: kr.sh <jobs.json> <outdir>
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/xdg/mesa
mkdir -p "$2" "$MESA_SHADER_CACHE_DIR"
cd "$WT"
timeout 1500 nice -n 19 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  -s "$S/bin/kritik_render.gd" -- "--jobs=$1" "--outdir=$2" 2>&1 | grep -vE "^ALSA|^\s*$|V-Sync|set_use_vsync|^Godot Engine|^OpenGL API" | awk '!seen[$0]++' | tail -20
