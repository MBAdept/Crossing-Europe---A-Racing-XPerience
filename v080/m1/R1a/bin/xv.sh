#!/usr/bin/env bash
# Scratch helper of package R1a: Godot under Xvfb with software OpenGL in the worktree, absolute XDG_DATA_HOME and
# one shared Mesa shader cache. Usage: xv.sh <godot arguments…>   (SCREEN=1280x800 for another screen size)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1
SCREEN=${SCREEN:-1280x720}
mkdir -p "$S/xdg" "$S/tmp" "$S/mesa"
export XDG_DATA_HOME="$S/xdg" MESA_SHADER_CACHE_DIR="$S/mesa"
cd "$W" || exit 1
exec nice -n 10 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution "$SCREEN" --fixed-fps 60 "$@"
