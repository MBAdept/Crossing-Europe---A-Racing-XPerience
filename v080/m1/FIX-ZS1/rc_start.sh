#!/usr/bin/env bash
# usage: rc_start.sh <log> [save dir] – runs the render check "Start bei km 0" once
set -uo pipefail
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
export XDG_DATA_HOME=$S/xdg_rc
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
SAVE=()
[ -n "${2:-}" ] && SAVE=("--save=$2")
nice -n 5 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --fixed-fps 60 -s res://tests/race3d/render/check_start_km0.gd -- --graphics=modern --gfx-sync \
	--audio-sync "${SAVE[@]}" >"$1" 2>&1
echo "exit $?" >>"$1"
