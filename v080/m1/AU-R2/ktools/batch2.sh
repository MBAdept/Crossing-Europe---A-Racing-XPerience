#!/bin/bash
# AU-R2 batch 2: M3 comparison at the AU-R slab level, crashes (M2/M4, 60 each), perf on concrete (M1, before/after
# alternately), one after the other, nice 19.   batch2.sh [steps...]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2
K=$S/ktools
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-3
export XDG_DATA_HOME="$S/xdg"
mkdir -p "$S/cap/crash" "$S/logs"
g() {
	local tree=$1 log=$2 to=$3 script=$4; shift 4
	local dir="$WT"
	[ "$tree" = before ] && dir="$S/before"
	local t0=$(date +%s)
	( cd "$dir" && nice -n 19 timeout "$to" godot --headless --path . --audio-driver Dummy -s "$script" -- --graphics=arcade "$@" ) > "$S/logs/$log.log" 2>&1
	echo "--- $tree $log exit $? in $(( $(date +%s) - t0 )) s ($(date +%T))"
	grep -E "SCRIPT ERROR|Parse Error|leaked|still in use|kr_crash:|PERF road|PERF feed" "$S/logs/$log.log" | cut -c1-220 | head -6
}
steps=${*:-m3b crash_car crash_truck crash_truck10 perf}
for s in $steps; do
	echo "=== $s $(date +%T)"
	case $s in
		m3b) bash "$K/run_cap.sh" after "$K/plan_m3b.json" M3B ;;
		crash_car) g after crash_car 900 "$K/kr_crash.gd" --out="$S/cap/crash/car.wav" --n=60 --rel=130 --seed=777 ;;
		crash_truck) g after crash_truck 900 "$K/kr_crash.gd" --out="$S/cap/crash/truck.wav" --n=60 --rel=130 --heavy --seed=778 ;;
		crash_truck10) g after crash_truck10 900 "$K/kr_crash.gd" --out="$S/cap/crash/truck10.wav" --n=60 --rel=130 --heavy --seed=778 --truck=-10 ;;
		perf)
			for rep in 1 2 3; do
				for t in after before; do
					g "$t" "perfconc${rep}_$t" 300 "$K/kr_perf_conc.gd"
				done
			done ;;
	esac
done
echo "=== batch2 fertig $(date +%T)"
