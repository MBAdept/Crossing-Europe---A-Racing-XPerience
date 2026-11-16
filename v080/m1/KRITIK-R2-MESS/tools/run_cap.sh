#!/bin/bash
# KRITIK-R2-MESS: run km_capture.gd with a plan on a head copy (obj | c1 | r), nice 19, absolute XDG_DATA_HOME.
#   run_cap.sh <head> <plan.json> <outname> [--only=a,b] [--seed=N] [more args]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS
head=$1; plan=$2; name=$3; shift 3
dir="$W/heads/$head"
[ -d "$dir" ] || { echo "head?"; exit 2; }
mkdir -p "$W/cap/$head/$name" "$W/logs" "$W/xdg/run"
cd "$dir" || exit 2
export XDG_DATA_HOME="$W/xdg/run"
t0=$(date +%s)
nice -n 19 timeout 3000 godot --headless --path . --audio-driver Dummy -s "$W/tools/km_capture.gd" -- --graphics=arcade \
	--plan="$plan" --out-dir="$W/cap/$head/$name" "$@" > "$W/logs/cap_${head}_${name}.log" 2>&1
rc=$?
echo "$head $name exit $rc in $(( $(date +%s) - t0 )) s"
grep -E "kr_capture:|SCRIPT ERROR|Parse Error|ERROR|leaked|still in use" "$W/logs/cap_${head}_${name}.log" | cut -c1-260
