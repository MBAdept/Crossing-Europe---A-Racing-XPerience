#!/bin/bash
# R7a: run unit tests with a filter.  ut.sh <filter>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
x=$S/xdg/ut_$$
rm -rf "$x"; mkdir -p "$x"
cd "$WT" || exit 1
XDG_DATA_HOME=$x nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- "--filter=$1" 2>&1 | grep -vE '^\s*$|^Godot Engine'
rm -rf "$x"
