#!/usr/bin/env bash
# Runs godot in the AU-A worktree with a scratch XDG_DATA_HOME (Rule 8). Usage: g.sh [XDG=<name>] <godot args…>
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
XDG_NAME=xdg
if [[ "${1:-}" == XDG=* ]]; then
	XDG_NAME="${1#XDG=}"
	shift
fi
export XDG_DATA_HOME="$W/$XDG_NAME"
mkdir -p "$XDG_DATA_HOME"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3 || exit 1
exec nice -n 10 godot "$@"
