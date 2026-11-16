#!/bin/bash
# KRITIK-R batch 2: trigger logs (after), shares (both), slab phase (both), crashes (both + after with the AU-C1
# levels), worst case (both), perf (both), arcade lean (after). One job at a time, nice 19.
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
KF=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-FAHRBAHN
export XDG_DATA_HOME="$K/xdg"
mkdir -p "$K/logs" "$K/cap/crash" "$K/cap/slab" "$K/cap/worst"
g() {
	# g <tree> <logname> <timeout s> <script> [args...]
	local tree=$1 log=$2 to=$3 script=$4; shift 4
	local t0=$(date +%s)
	( cd "$K/$tree" && nice -n 19 timeout "$to" godot --headless --path . --audio-driver Dummy -s "$script" -- --graphics=arcade "$@" ) > "$K/logs/$log.log" 2>&1
	echo "--- $tree $log exit $? in $(( $(date +%s) - t0 )) s ($(date +%T))"
	grep -E "SCRIPT ERROR|Parse Error|leaked|still in use|FEHLER|kr_|PERF|CHECK|DONE|STOP|ERGEBNIS" "$K/logs/$log.log" | cut -c1-220 | head -12
}
steps=${*:-trig shares slab crash worst perf lean}
for s in $steps; do
	case $s in
		trig)
			g after trig_kiel_hamburg 900 "$KF/trigger_log.gd" --sound=modern --stage=kiel_hamburg --from=kiel
			g after trig_mailand_venedig 900 "$KF/trigger_log.gd" --sound=modern --stage=mailand_venedig --start-km=220
			g after trig_luettich_paris 900 "$KF/trigger_log.gd" --sound=modern --stage=luettich_paris --start-km=340
			g after trig_bern_mailand 900 "$KF/trigger_log.gd" --sound=modern --stage=bern_mailand --start-km=95 --stop-km=215 ;;
		shares)
			g after shares_after 1800 "$K/tools/kr_shares.gd"
			g before shares_before 1800 "$K/tools/kr_shares.gd" ;;
		slab)
			g after slab_after 600 "$K/tools/kr_slab.gd" --out="$K/cap/slab/after"
			g before slab_before 600 "$K/tools/kr_slab.gd" --out="$K/cap/slab/before" ;;
		crash)
			g after crash_after_car 900 "$K/tools/kr_crash.gd" --out="$K/cap/crash/after_car.wav" --n=24 --rel=130 --seed=777 --squeal --pass
			g after crash_after_truck 900 "$K/tools/kr_crash.gd" --out="$K/cap/crash/after_truck.wav" --n=16 --rel=130 --heavy --seed=778
			g after crash_afterold_car 900 "$K/tools/kr_crash.gd" --out="$K/cap/crash/afterold_car.wav" --n=24 --rel=130 --seed=777 --hh=-9
			g after crash_afterold_truck 900 "$K/tools/kr_crash.gd" --out="$K/cap/crash/afterold_truck.wav" --n=16 --rel=130 --heavy --seed=778 --truck=-10
			g before crash_before_car 900 "$K/tools/kr_crash.gd" --out="$K/cap/crash/before_car.wav" --n=24 --rel=130 --seed=777 --squeal --pass
			g before crash_before_truck 900 "$K/tools/kr_crash.gd" --out="$K/cap/crash/before_truck.wav" --n=16 --rel=130 --heavy --seed=778 ;;
		worst)
			g after worst_after 300 "$K/tools/kr_worst.gd" --out="$K/cap/worst/after.wav"
			g before worst_before 300 "$K/tools/kr_worst.gd" --out="$K/cap/worst/before.wav" ;;
		perf)
			g after perf_after 300 "$KF/perf_auc1.gd"
			g before perf_before 300 "$KF/perf_auc1.gd" ;;
		lean)
			g after arcade_lean 600 res://tests/unit/audio_modern/check_arcade_lean.gd ;;
	esac
done
echo "=== batch2 fertig $(date +%T)"
