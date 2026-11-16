#!/usr/bin/env bash
# start-up time of two exported executables, alternating: startup_time_export.sh <old exe> <new exe> <scratch> <mode headless|title|stage> <runs>
set -uo pipefail
A=$1; B=$2; Q=$3; MODE=$4; RUNS=$5
export MESA_SHADER_CACHE_DIR=$Q/mesa_cache
STAGE_ARGS="--stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup"
one() { local exe=$1 xdg=$2 extra=$3 t0 t1
	t0=$(date +%s%N)
	case "$MODE" in
	headless) XDG_DATA_HOME=$xdg "$exe" --headless --quit-after 30 -- $extra >/dev/null 2>&1 ;;
	title) XDG_DATA_HOME=$xdg xvfb-run -a -s "-screen 0 1280x720x24" "$exe" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --quit-after 30 -- $extra >/dev/null 2>&1 ;;
	stage) XDG_DATA_HOME=$xdg xvfb-run -a -s "-screen 0 1280x720x24" "$exe" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 --quit-after 30 -- $STAGE_ARGS $extra >/dev/null 2>&1 ;;
	esac
	t1=$(date +%s%N); echo $(( (t1 - t0) / 1000000 )); }
mkdir -p $Q/xdg_time_ea $Q/xdg_time_eb
one "$A" $Q/xdg_time_ea "" >/dev/null; one "$B" $Q/xdg_time_eb "--graphics=arcade" >/dev/null
TA=(); TB=()
for i in $(seq 1 "$RUNS"); do
	if [ $((i % 2)) -eq 1 ]; then TA+=($(one "$A" $Q/xdg_time_ea "")); TB+=($(one "$B" $Q/xdg_time_eb "--graphics=arcade"))
	else TB+=($(one "$B" $Q/xdg_time_eb "--graphics=arcade")); TA+=($(one "$A" $Q/xdg_time_ea "")); fi
done
python3 - "$MODE" "${TA[*]}" "${TB[*]}" <<'PY'
import sys, statistics as st
mode = sys.argv[1]; a = sorted(map(int, sys.argv[2].split())); b = sorted(map(int, sys.argv[3].split()))
def s(x): return 'n=%d min %d median %d mean %.0f max %d ms' % (len(x), x[0], st.median(x), st.mean(x), x[-1])
print('EXPORT-START %-8s v0.7.0-Export   %s' % (mode, s(a)))
print('EXPORT-START %-8s neuer Export    %s' % (mode, s(b)))
print('EXPORT-START %-8s Unterschied: median %+d ms (%+.1f %%), min %+d ms (%+.1f %%)' % (mode, st.median(b) - st.median(a), 100.0 * (st.median(b) - st.median(a)) / st.median(a), b[0] - a[0], 100.0 * (b[0] - a[0]) / a[0]))
PY
