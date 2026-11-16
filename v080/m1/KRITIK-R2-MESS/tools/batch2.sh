#!/bin/bash
# KRITIK-R2-MESS batch 2: R1 as played (plan A) obj x2 seeds + c1; V3 cruising (plan V) obj; cobble repeats (plan C)
# obj + c1; crashes obj (+ c1); worst case obj + c1. One job after the other, nice 19.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS
T=$W/tools
export XDG_DATA_HOME="$W/xdg/run"
mkdir -p "$W/cap/crash" "$W/cap/worst" "$W/logs"
g() {
	local head=$1 log=$2 to=$3 script=$4; shift 4
	local t0=$(date +%s)
	( cd "$W/heads/$head" && nice -n 19 timeout "$to" godot --headless --path . --audio-driver Dummy -s "$script" -- --graphics=arcade "$@" ) > "$W/logs/$log.log" 2>&1
	echo "--- $head $log exit $? in $(( $(date +%s) - t0 )) s ($(date +%T))"
	grep -E "SCRIPT ERROR|Parse Error|leaked|still in use|kr_crash:|worst|PERF road|PERF feed|PERF impact" "$W/logs/$log.log" | cut -c1-220 | head -6
}
steps=${*:-Aobj Vobj Cobj Cc1 crash_car crash_truck A2obj Ac1 worst_obj worst_c1 crash_car_c1 crash_truck_c1}
for s in $steps; do
	echo "=== $s $(date +%T)"
	case $s in
		Aobj) bash $T/run_cap.sh obj $T/plan_mA.json A --seed=7301 ;;
		A2obj) bash $T/run_cap.sh obj $T/plan_mA.json A2 --seed=7401 ;;
		Ac1) bash $T/run_cap.sh c1 $T/plan_mA.json A --seed=7301 ;;
		Vobj) bash $T/run_cap.sh obj $T/plan_mV.json V --seed=7501 ;;
		Cobj) bash $T/run_cap.sh obj $T/plan_mC.json C --seed=7601 ;;
		Cc1) bash $T/run_cap.sh c1 $T/plan_mC.json C --seed=7601 ;;
		crash_car) g obj crash_car_obj 900 "$T/kr_crash.gd" --out="$W/cap/crash/car_obj.wav" --n=60 --rel=130 --seed=9311 ;;
		crash_truck) g obj crash_truck_obj 900 "$T/kr_crash.gd" --out="$W/cap/crash/truck_obj.wav" --n=60 --rel=130 --heavy --seed=9312 ;;
		crash_car_c1) g c1 crash_car_c1 900 "$T/kr_crash.gd" --out="$W/cap/crash/car_c1.wav" --n=60 --rel=130 --seed=9311 ;;
		crash_truck_c1) g c1 crash_truck_c1 900 "$T/kr_crash.gd" --out="$W/cap/crash/truck_c1.wav" --n=60 --rel=130 --heavy --seed=9312 ;;
		worst_obj) g obj worst_obj 300 "$T/kr_worst.gd" --out="$W/cap/worst/obj.wav" ;;
		worst_c1) g c1 worst_c1 300 "$T/kr_worst.gd" --out="$W/cap/worst/c1.wav" ;;
	esac
done
echo "=== batch2 fertig $(date +%T)"
