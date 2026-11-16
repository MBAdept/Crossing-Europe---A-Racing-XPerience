#!/usr/bin/env bash
# xbench.sh <where> [secs] [extra args] – the scratch bench under Xvfb (render counters)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-2
R2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R2
W=$1
S=${2:-10}
shift
[ $# -gt 0 ] && shift
export XDG_DATA_HOME=$R2/xdg
export MESA_SHADER_CACHE_DIR=$R2/mesa
cd "$WT" || exit 1
nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --fixed-fps 60 -s "$R2/bench.gd" -- --graphics=modern --where="$W" --secs="$S" "$@" 2>&1 | grep -E "BENCH|ERROR|SCRIPT" | head -6
