#!/bin/bash
# KRITIK-R: run kr_capture.gd with a plan on a tree.  run_cap.sh <before|after> <plan.json> <outname> [--only=a,b]
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
tree=$1; plan=$2; name=$3; shift 3
mkdir -p "$K/cap/$tree/$name" "$K/logs"
cd "$K/$tree" || exit 2
export XDG_DATA_HOME="$K/xdg"
t0=$(date +%s)
nice -n 19 timeout 3000 godot --headless --path . --audio-driver Dummy -s "$K/tools/kr_capture.gd" -- --graphics=arcade \
	--plan="$plan" --out-dir="$K/cap/$tree/$name" "$@" > "$K/logs/cap_${tree}_${name}.log" 2>&1
rc=$?
echo "$tree $name exit $rc in $(( $(date +%s) - t0 )) s"
grep -E "kr_capture:|SCRIPT ERROR|Parse Error|ERROR|leaked|still in use" "$K/logs/cap_${tree}_${name}.log" | cut -c1-260
