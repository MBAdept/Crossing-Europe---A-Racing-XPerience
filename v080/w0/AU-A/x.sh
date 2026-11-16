#!/usr/bin/env bash
# Runs godot under Xvfb (software OpenGL, Dummy audio) in the AU-A worktree. Usage: x.sh [XDG=<name>] <godot args…>
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
XDG_NAME=xdg_x
if [[ "${1:-}" == XDG=* ]]; then
	XDG_NAME="${1#XDG=}"
	shift
fi
export XDG_DATA_HOME="$W/$XDG_NAME"
export MESA_SHADER_CACHE_DIR="$W/mesa_cache"
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3 || exit 1
exec nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy "$@"
