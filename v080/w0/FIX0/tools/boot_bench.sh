#!/usr/bin/env bash
# engine --benchmark numbers (Load Autoloads, Load Game, Main::Start) of several trees/executables, alternating.
#   boot_bench.sh <runs> <label=cmd prefix>…   e.g.  v070="godot --headless --path /x"
set -uo pipefail
RUNS=$1; shift
Q=$BOOT_Q
declare -A CMD; LABELS=()
for a in "$@"; do l=${a%%=*}; CMD[$l]=${a#*=}; LABELS+=("$l"); mkdir -p $Q/xdg_bench_$l; done
OUT=$Q/logs/boot_bench_$$.txt; : > $OUT
for i in $(seq 0 "$RUNS"); do
	for l in "${LABELS[@]}"; do
		extra="--graphics=arcade"; [[ $l == v070* ]] && extra=""
		XDG_DATA_HOME=$Q/xdg_bench_$l ${CMD[$l]} --benchmark --quit-after 3 -- $extra 2>&1 | awk -v l=$l -v i=$i '/BENCHMARK:/ {n++} n==1 && /Load Autoloads|Load Game|Main::Start|Main::Setup2|Main::Setup:/ {gsub(/^[ \t-]+/, ""); split($0, a, ": "); print l, i, a[1], a[2] + 0}' >> $OUT
	done
done
python3 - $OUT <<'PY'
import sys, collections, statistics as st
d = collections.defaultdict(list)
for line in open(sys.argv[1]):
    p = line.split()
    if p[1] == '0': continue   # warm-up
    d[(p[0], ' '.join(p[2:-1]))].append(float(p[-1]))
labels = sorted(set(k[0] for k in d)); keys = ['Load Autoloads', 'Load Game', 'Main::Start', 'Main::Setup', 'Main::Setup2']
for k in keys:
    print(k)
    base = None
    for l in labels:
        x = sorted(d[(l, k)])
        if not x: continue
        if base is None: base = st.median(x)
        print('   %-10s n=%d  min %7.1f  median %7.1f  max %7.1f ms   (median %+6.1f ms vs %s)' % (l, len(x), x[0], st.median(x), x[-1], st.median(x) - base, labels[0]))
PY
