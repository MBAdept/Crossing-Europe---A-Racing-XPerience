#!/usr/bin/env bash
# Runs godot in the pristine v0.7.0 tree (git archive of the tag) with its own scratch XDG_DATA_HOME.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
export XDG_DATA_HOME="$W/xdg_v070"
mkdir -p "$XDG_DATA_HOME"
cd "$W/v070" || exit 1
exec nice -n 10 godot "$@"
