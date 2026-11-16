#!/usr/bin/env bash
# AU-R: constant-speed captures. usage: run_cap.sh <tree> <outdir> [plan.json] [extra args…]
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R
TREE=$1; OUT=$2; PLAN=${3:-$S/plan_const.json}; shift 3 || shift $#
mkdir -p "$OUT" "$S/xdg_cap"
cd "$TREE"
XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 1200 godot --headless --path . -s "$S/cap_const.gd" -- --graphics=arcade \
	--plan="$PLAN" --out-dir="$OUT" "$@" 2>&1 | grep -E "cap_const|ERROR|SCRIPT|rror" | cut -c1-220
echo "== fertig $?"
