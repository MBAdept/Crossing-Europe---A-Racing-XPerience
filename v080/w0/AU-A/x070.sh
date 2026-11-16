#!/usr/bin/env bash
# Runs godot under Xvfb (software OpenGL, Dummy audio) in the pristine v0.7.0 tree.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
export XDG_DATA_HOME="$W/xdg_v070x"
export MESA_SHADER_CACHE_DIR="$W/mesa_cache"
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$W/v070" || exit 1
exec nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy "$@"
