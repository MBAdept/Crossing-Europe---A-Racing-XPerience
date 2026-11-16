#!/usr/bin/env bash
# UI1 scratch helper: headless Godot run in the worktree with an own absolute XDG_DATA_HOME.
#   gd.sh <xdg name> <godot args…>        env: TIMEOUT (default 600)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-2
BASE=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/UI1
XDG=$1; shift
export XDG_DATA_HOME="$BASE/xdg/$XDG"
mkdir -p "$XDG_DATA_HOME"
cd "$WT"
nice -n 10 timeout "${TIMEOUT:-600}" godot --headless --path . "$@" 2>&1 | grep -vE "^\s*$|^Godot Engine"
exit "${PIPESTATUS[0]}"
