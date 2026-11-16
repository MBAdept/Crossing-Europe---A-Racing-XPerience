#!/bin/bash
# KRITIK-R batch 4: direction check of the concrete decision (both), fuel lane per frame (both). One at a time, nice 19.
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
export XDG_DATA_HOME="$K/xdg"
g() {
	local tree=$1 log=$2 to=$3 script=$4; shift 4
	local t0=$(date +%s)
	( cd "$K/$tree" && nice -n 19 timeout "$to" godot --headless --path . --audio-driver Dummy -s "$script" -- --graphics=arcade "$@" ) > "$K/logs/$log.log" 2>&1
	echo "--- $tree $log exit $? in $(( $(date +%s) - t0 )) s ($(date +%T))"
	grep -E "SCRIPT ERROR|Parse Error|leaked|still in use|DONE|FUEL" "$K/logs/$log.log" | cut -c1-220 | head -6
}
g after dirs_after 600 "$K/tools/kr_dirs.gd"
g before dirs_before 600 "$K/tools/kr_dirs.gd"
g after fuel_after 600 "$K/tools/kr_fuel.gd" --sound=modern
g before fuel_before 600 "$K/tools/kr_fuel.gd" --sound=modern
for t in after before; do
	bash "$K/tools/run_cap.sh" "$t" "$K/tools/plan_t.json" T
done
mkdir -p "$K/cap/crash"
g after glass60_after 600 "$K/tools/kr_crash.gd" --out="$K/cap/crash/glass60_after.wav" --n=60 --rel=60 --seed=901 --gap=0.3
g after perfconc_after 300 "$K/tools/kr_perf_conc.gd"
g before perfconc_before 300 "$K/tools/kr_perf_conc.gd"
grep -h "PERF" "$K/logs/perfconc_after.log" "$K/logs/perfconc_before.log" | cut -c1-200
echo "=== batch4 fertig $(date +%T)"
