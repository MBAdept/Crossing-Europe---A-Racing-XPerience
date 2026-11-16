#!/usr/bin/env bash
# topviews.sh <out folder> – data of the top views (check_terrain_plan --dump) and the pictures (topview.py)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-2
R2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R2
OUT=$1
mkdir -p "$OUT" "$R2/plan_final"
cd "$WT" || exit 1
XDG_DATA_HOME=$R2/xdg nice -n 10 timeout 600 godot --headless --path . -s res://tests/race3d/check_terrain_plan.gd -- --verbose "--dump=$R2/plan_final" > "$R2/plan_final/check.log" 2>&1
echo "exit $?"
grep -E "CHECK|==>" "$R2/plan_final/check.log"
for id in T1 T2 T3 T4; do
	python3 "$R2/topview.py" "$R2/plan_final/plan_$id.json" "$OUT/draufsicht_$id.png" && echo "$OUT/draufsicht_$id.png"
done
