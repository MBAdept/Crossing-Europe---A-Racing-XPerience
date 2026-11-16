#!/usr/bin/env bash
# stage_time.sh <runs> <headless|xvfb> label=tree …
set -uo pipefail
RUNS=$1; MODE=$2; shift 2
Q=$BOOT_Q; export MESA_SHADER_CACHE_DIR=$Q/mesa_cache
OUT=$Q/logs/stage_time_$$.txt; : > $OUT
for i in $(seq 0 "$RUNS"); do
	for a in "$@"; do l=${a%%=*}; tree=${a#*=}; mkdir -p $Q/xdg_bench_$l
		if [ "$MODE" = headless ]; then
			XDG_DATA_HOME=$Q/xdg_bench_$l godot --headless --path $tree --fixed-fps 60 -s $Q/probes/qa_stage_time_probe.gd -- --graphics=arcade 2>&1 | awk -v l=$l -v i=$i '/^STAGE-/ {print l, i, $0}' >> $OUT
		else
			XDG_DATA_HOME=$Q/xdg_bench_$l xvfb-run -a -s "-screen 0 1280x720x24" godot --path $tree --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $Q/probes/qa_stage_time_probe.gd -- --graphics=arcade 2>&1 | awk -v l=$l -v i=$i '/^STAGE-/ {print l, i, $0}' >> $OUT
		fi
	done
done
python3 - $OUT <<'PY'
import sys, collections, statistics as st
d = collections.defaultdict(list)
for line in open(sys.argv[1]):
    p = line.split()
    if p[1] == '0': continue
    if p[2] == 'STAGE-TIME':
        k = p[3]
        d[(p[0], 'stage %s: load+instantiate' % k)].append(float(p[4])); d[(p[0], 'stage %s: add_child (_ready, _build)' % k)].append(float(p[5])); d[(p[0], 'stage %s: first 30 frames' % k)].append(float(p[6]))
    else:
        d[(p[0], 'boot until the probe starts')].append(float(p[3]))
labels = sorted(set(k[0] for k in d)); keys = sorted(set(k[1] for k in d))
for k in keys:
    print(k); base = None
    for l in labels:
        x = sorted(d[(l, k)])
        if base is None: base = st.median(x)
        print('   %-8s n=%d  min %8.1f  median %8.1f  max %8.1f ms  (median %+7.1f ms, %+5.1f %%)' % (l, len(x), x[0], st.median(x), x[-1], st.median(x) - base, 100 * (st.median(x) - base) / base))
PY
