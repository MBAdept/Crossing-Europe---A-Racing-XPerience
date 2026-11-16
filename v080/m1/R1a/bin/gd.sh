#!/usr/bin/env bash
# Scratch helper of package R1a: headless Godot in the worktree with an absolute XDG_DATA_HOME.
# Usage: gd.sh <godot arguments…>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R1a
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b561c53-566-1
mkdir -p "$S/xdg" "$S/tmp"
export XDG_DATA_HOME="$S/xdg"
cd "$W" || exit 1
exec nice -n 10 godot --headless --path . "$@"
