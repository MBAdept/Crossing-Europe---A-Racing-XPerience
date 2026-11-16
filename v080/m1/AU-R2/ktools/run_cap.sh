#!/bin/bash
# AU-R2 (copy of KRITIK-R run_cap.sh): run kr_capture.gd with a plan on a tree.
#   run_cap.sh <before|after> <plan.json> <outname> [--only=a,b] [more args for kr_capture.gd]
# before = AU-C1 copy (4209268), after = the AU-R2 worktree.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-3
tree=$1; plan=$2; name=$3; shift 3
case $tree in
	before) dir="$S/before" ;;
	after) dir="$WT" ;;
	*) echo "tree?"; exit 2 ;;
esac
mkdir -p "$S/cap/$tree/$name" "$S/logs" "$S/xdg"
cd "$dir" || exit 2
export XDG_DATA_HOME="$S/xdg"
t0=$(date +%s)
nice -n 19 timeout 3000 godot --headless --path . --audio-driver Dummy -s "$S/ktools/kr_capture.gd" -- --graphics=arcade \
	--plan="$plan" --out-dir="$S/cap/$tree/$name" "$@" > "$S/logs/cap_${tree}_${name}.log" 2>&1
rc=$?
echo "$tree $name exit $rc in $(( $(date +%s) - t0 )) s"
grep -E "kr_capture:|SCRIPT ERROR|Parse Error|ERROR|leaked|still in use" "$S/logs/cap_${tree}_${name}.log" | cut -c1-260
