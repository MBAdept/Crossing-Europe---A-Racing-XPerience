#!/usr/bin/env bash
# Runs the switch stress probe with a timeout. Usage: stress.sh <log name> <timeout s> [flags…]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="$1"
TO="$2"
shift 2
export XDG_DATA_HOME="$W/xdg_stress"
mkdir -p "$XDG_DATA_HOME" "$W/logs"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3 || exit 1
START=$(date +%s)
timeout -s KILL "$TO" nice -n 10 godot --headless --path . -s "$W/probe/stress_switch.gd" -- "$@" >"$W/logs/$NAME.log" 2>&1
CODE=$?
END=$(date +%s)
grep -E "^iter|STRESS|ERROR|WARNING" "$W/logs/$NAME.log" | tail -3
echo "EXIT $CODE  $((END - START)) s  ($*)"
