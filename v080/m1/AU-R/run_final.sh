#!/usr/bin/env bash
# AU-R final recordings on the committed state (nice 19, one after the other). usage: run_final.sh [step …]
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R
NEW=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1
OLD=$S/old
mkdir -p "$S/xdg_cap" "$S/final"
g() {   # tree script args…
	local tree=$1; shift
	local script=$1; shift
	(cd "$tree" && XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 900 godot --headless --path . -s "$script" -- --graphics=arcade "$@" 2>&1)
}
steps=${*:-const char_new char_old drive_new drive_old drive_mix bridge_new bridge_old crash snow}
for st in $steps; do
	echo "=== $st $(date +%H:%M:%S)"
	case $st in
		const) g "$NEW" "$S/cap_const.gd" --plan="$S/plan_const.json" --out-dir="$S/cap_after3" | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-160 ;;
		char_new) g "$NEW" "$S/cap_const.gd" --plan="$S/plan_char.json" --out-dir="$S/char_new" | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-160 ;;
		char_old) g "$OLD" "$S/cap_const.gd" --plan="$S/plan_char.json" --out-dir="$S/char_old" | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-160 ;;
		drive_new) g "$NEW" "$S/drive_ab.gd" --out="$S/final/drive_new.wav" --cobble-km=88.4 | grep -E "drive_demo|Grenze|ERROR|SCRIPT" | cut -c1-200 ;;
		drive_old) g "$OLD" "$S/drive_ab.gd" --out="$S/final/drive_old.wav" --cobble-km=88.4 | grep -E "drive_demo|Grenze|ERROR|SCRIPT" | cut -c1-200 ;;
		drive_mix) g "$NEW" "$S/drive_ab.gd" --out="$S/final/drive_mix.wav" --cobble-km=88.4 --music | grep -E "drive_demo|ERROR|SCRIPT" | cut -c1-200 ;;
		bridge_new) g "$NEW" "$S/scene_ab.gd" --scenario=bruecke --out="$S/final/bridge_new.wav" | grep -E "scene_ab|Fugen|ERROR|SCRIPT" | cut -c1-300 ;;
		bridge_old) g "$OLD" "$S/scene_ab.gd" --scenario=bruecke --out="$S/final/bridge_old.wav" | grep -E "scene_ab|Fugen|ERROR|SCRIPT" | cut -c1-300 ;;
		crash) g "$NEW" "$S/scene_ab.gd" --scenario=aufprall --out="$S/final/crash_new.wav" | grep -E "scene_ab|ERROR|SCRIPT" | cut -c1-200 ;;
		snow) g "$NEW" "$S/scene_ab.gd" --scenario=schnee --out="$S/final/snow_new.wav" | grep -E "scene_ab|ERROR|SCRIPT" | cut -c1-200 ;;
	esac
done
echo "=== fertig $(date +%H:%M:%S)"
