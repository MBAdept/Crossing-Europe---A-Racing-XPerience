#!/bin/bash
# rct.sh <tag> <check file name> [extra args] – one render check under Xvfb (nice 19), pictures in rc/<tag>/, log rc/<tag>.log
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
TAG=$1; NAME=$2; shift 2
export XDG_DATA_HOME=$R4/xdg_rc
export MESA_SHADER_CACHE_DIR=$R4/mesa
mkdir -p "$XDG_DATA_HOME" "$R4/rc/$TAG"
cd "$WT" || exit 2
T0=$(date +%s)
nice -n ${NICE:-19} timeout ${RC_TIMEOUT:-2400} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --fixed-fps 60 -s res://tests/race3d/render/$NAME.gd -- --graphics=modern --gfx-sync --audio-sync --save=$R4/rc/$TAG "$@" > "$R4/rc/$TAG.log" 2>&1
echo "exit=$? secs=$(( $(date +%s) - T0 ))" >> "$R4/rc/$TAG.log"
grep -E 'RENDER-CHECK|SCRIPT ERROR|SHADER ERROR|Shader compilation|ERROR:|exit=' "$R4/rc/$TAG.log" | head -40
