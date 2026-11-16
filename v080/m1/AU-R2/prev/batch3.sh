#!/bin/bash
# AU-R2: the recordings of the previews that change in this round (AU-R's run_final.sh steps), nice 19, one after
# the other.   batch3.sh [drive_old drive_new drive_mix crash]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2
P=$S/prev
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-3
mkdir -p "$S/final" "$S/xdg_cap"
g() {
	local tree=$1; shift
	local script=$1; shift
	(cd "$tree" && XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 900 godot --headless --path . -s "$script" -- --graphics=arcade "$@" 2>&1)
}
steps=${*:-drive_old drive_new drive_mix}
for st in $steps; do
	echo "=== $st $(date +%H:%M:%S)"
	case $st in
		drive_new) g "$WT" "$P/drive_ab.gd" --out="$S/final/drive_new.wav" --cobble-km=88.4 | grep -E "drive_demo|Grenze|ERROR|SCRIPT" | cut -c1-200 ;;
		drive_old) g "$S/before" "$P/drive_ab.gd" --out="$S/final/drive_old.wav" --cobble-km=88.4 | grep -E "drive_demo|Grenze|ERROR|SCRIPT" | cut -c1-200 ;;
		drive_mix) g "$WT" "$P/drive_ab.gd" --out="$S/final/drive_mix.wav" --cobble-km=88.4 --music | grep -E "drive_demo|ERROR|SCRIPT" | cut -c1-200 ;;
		crash) g "$WT" "$P/scene_ab.gd" --scenario=aufprall --out="$S/final/crash_new.wav" | grep -E "scene_ab|ERROR|SCRIPT" | cut -c1-200 ;;
	esac
done
echo "=== batch3 fertig $(date +%H:%M:%S)"
