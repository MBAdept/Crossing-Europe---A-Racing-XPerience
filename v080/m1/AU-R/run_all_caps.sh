#!/usr/bin/env bash
# AU-R: all real-time recordings, one after the other (nice 19). usage: run_all_caps.sh [step …]
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R
NEW=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1
OLD=$S/old
mkdir -p "$S/xdg_cap" "$S/demo"
g() {   # tree script args…
	local tree=$1; shift
	local script=$1; shift
	(cd "$tree" && XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 900 godot --headless --path . -s "$script" -- --graphics=arcade "$@" 2>&1)
}
steps=${*:-sync const drive_new drive_old bridge_new bridge_old crash snow}
for st in $steps; do
	echo "=== $st $(date +%H:%M:%S)"
	case $st in
		sync) g "$NEW" "$S/slab_sync.gd" | grep -E "SYNC|SUMMARY|ERROR|SCRIPT" ;;
		const) g "$NEW" "$S/cap_const.gd" --plan="$S/plan_const.json" --out-dir="$S/cap_after" | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-200 ;;
		drive_new) g "$NEW" "$S/drive_ab.gd" --out="$S/demo/drive_new.wav" | grep -E "drive_demo|phase|Grenze|ERROR|SCRIPT" | cut -c1-200 ;;
		drive_old) g "$OLD" "$S/drive_ab.gd" --out="$S/demo/drive_old.wav" | grep -E "drive_demo|phase|Grenze|ERROR|SCRIPT" | cut -c1-200 ;;
		bridge_new) g "$NEW" "$S/scene_ab.gd" --scenario=bruecke --out="$S/demo/bridge_new.wav" | grep -E "scene_ab|Fugen|ERROR|SCRIPT" | cut -c1-400 ;;
		bridge_old) g "$OLD" "$S/scene_ab.gd" --scenario=bruecke --out="$S/demo/bridge_old.wav" | grep -E "scene_ab|Fugen|ERROR|SCRIPT" | cut -c1-400 ;;
		crash) g "$NEW" "$S/scene_ab.gd" --scenario=aufprall --out="$S/demo/crash_new.wav" | grep -E "scene_ab|mark|ERROR|SCRIPT" | cut -c1-200 ;;
		crash_old) g "$OLD" "$S/scene_ab.gd" --scenario=aufprall --out="$S/demo/crash_old.wav" | grep -E "scene_ab|mark|ERROR|SCRIPT" | cut -c1-200 ;;
		snow) g "$NEW" "$S/scene_ab.gd" --scenario=schnee --out="$S/demo/snow_new.wav" | grep -E "scene_ab|mark|ERROR|SCRIPT" | cut -c1-200 ;;
	esac
done
echo "=== fertig $(date +%H:%M:%S)"
