#!/usr/bin/env bash
# Runs the generator repro in the pristine v0.7.0 tree (no AU-A code) with a timeout. Usage: repro.sh <name> <timeout> [flags]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="$1"
TO="$2"
shift 2
export XDG_DATA_HOME="$W/xdg_repro"
mkdir -p "$XDG_DATA_HOME" "$W/logs"
cd "$W/v070" || exit 1
START=$(date +%s)
timeout -s KILL "$TO" nice -n 10 godot --headless --path . -s "$W/probe/repro_generator.gd" -- "$@" >"$W/logs/$NAME.log" 2>&1
CODE=$?
END=$(date +%s)
grep -E "^iter|REPRO|ERROR|WARNING" "$W/logs/$NAME.log" | tail -2
echo "EXIT $CODE  $((END - START)) s  ($*)"
