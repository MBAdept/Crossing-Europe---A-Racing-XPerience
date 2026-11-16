#!/usr/bin/env bash
# AU-R batch 2: slab sync again, extra concrete segments, crash GR, worst case (new and old), trigger logs
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R
NEW=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1
OLD=$S/old
mkdir -p "$S/xdg_cap" "$S/demo" "$S/gr"
g() {
	local tree=$1; shift
	local script=$1; shift
	(cd "$tree" && XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 900 godot --headless --path . -s "$script" -- --graphics=arcade "$@" 2>&1)
}
steps=${*:-sync extra crash_new crash_old worst_new worst_old trig}
for st in $steps; do
	echo "=== $st $(date +%H:%M:%S)"
	case $st in
		sync) g "$NEW" "$S/slab_sync.gd" | grep -E "SYNC|SUMMARY|ERROR|SCRIPT" ;;
		extra) g "$NEW" "$S/cap_const.gd" --plan="$S/plan_extra.json" --out-dir="$S/cap_after2" | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-200 ;;
		extra_old) g "$OLD" "$S/cap_const.gd" --plan="$S/plan_extra.json" --out-dir="$S/cap_before2" --only=conc170_full | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-200 ;;
		crash_new) g "$NEW" "$S/crash_gr.gd" --out="$S/gr/crash130_new.wav" --n=24 --rel=130 | grep -E "crash_gr|ERROR|SCRIPT" ;;
		crash_old) g "$OLD" "$S/crash_gr.gd" --out="$S/gr/crash130_old.wav" --n=16 --rel=130 | grep -E "crash_gr|ERROR|SCRIPT" ;;
		crash_hh110) g "$NEW" "$S/crash_gr.gd" --out="$S/gr/crash130_hh110.wav" --n=24 --rel=130 --hh=-11.0 | grep -E "crash_gr|ERROR|SCRIPT" ;;
		crash_hh115) g "$NEW" "$S/crash_gr.gd" --out="$S/gr/crash130_hh115.wav" --n=24 --rel=130 --hh=-11.5 | grep -E "crash_gr|ERROR|SCRIPT" ;;
		crash_new_truck) g "$NEW" "$S/crash_gr.gd" --out="$S/gr/crash130t_new.wav" --n=16 --rel=130 --heavy | grep -E "crash_gr|ERROR|SCRIPT" ;;
		crash_old_truck) g "$OLD" "$S/crash_gr.gd" --out="$S/gr/crash130t_old.wav" --n=12 --rel=130 --heavy | grep -E "crash_gr|ERROR|SCRIPT" ;;
		worst_new) g "$NEW" "$S/worst_case2.gd" --out="$S/gr/worst_new.wav" --master=1.0 | grep -E "worst_case|ERROR|SCRIPT" | cut -c1-300 ;;
		worst_old) g "$OLD" "$S/worst_case2.gd" --out="$S/gr/worst_old.wav" --master=1.0 | grep -E "worst_case|ERROR|SCRIPT" | cut -c1-300 ;;
		trig) bash "$S/run_trig.sh" ;;
		c200_new) g "$NEW" "$S/cap_const.gd" --plan="$S/plan_c200.json" --out-dir="$S/cap_c200_new" | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-200 ;;
		c200_old) g "$OLD" "$S/cap_const.gd" --plan="$S/plan_c200.json" --out-dir="$S/cap_c200_old" | grep -E "cap_const|ERROR|SCRIPT" | cut -c1-200 ;;
	esac
done
echo "=== fertig2 $(date +%H:%M:%S)"
