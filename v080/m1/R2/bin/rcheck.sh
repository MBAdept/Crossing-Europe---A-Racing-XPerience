#!/usr/bin/env bash
# rcheck.sh <check file under res://> <log> [game args…]  – one render check under Xvfb, like tools/run_render_checks.sh
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-2
R2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R2
FILE=$1
LOGF=$2
shift 2
export XDG_DATA_HOME=$R2/xdg
export MESA_SHADER_CACHE_DIR=$R2/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$WT" || exit 1
nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "res://$FILE" -- --graphics=modern --gfx-sync --audio-sync "$@" >"$LOGF" 2>&1
code=$?
grep -E "^(RENDER-CHECK|GLOW-CHECK|FLIP-CHECK)|SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|^ERROR" "$LOGF" | head -40
echo "exit $code"
