#!/usr/bin/env bash
# wall time of "<cmd> --quit-after 30" for several labelled commands, alternating; prints min/median/mean.
set -uo pipefail
RUNS=$1; shift
Q=$BOOT_Q
declare -A CMD; LABELS=()
for a in "$@"; do l=${a%%=*}; CMD[$l]=${a#*=}; LABELS+=("$l"); mkdir -p $Q/xdg_bench_$l; done
OUT=$Q/logs/wall_bench_$$.txt; : > $OUT
for i in $(seq 0 "$RUNS"); do
	for l in "${LABELS[@]}"; do
		t0=$(date +%s%N)
		XDG_DATA_HOME=$Q/xdg_bench_$l ${CMD[$l]} --quit-after 30 >/dev/null 2>&1
		t1=$(date +%s%N)
		[ $i -gt 0 ] && echo "$l $(( (t1 - t0) / 1000000 ))" >> $OUT
	done
done
python3 - $OUT <<'PY'
import sys, collections, statistics as st
d = collections.defaultdict(list)
for line in open(sys.argv[1]):
    l, v = line.split(); d[l].append(int(v))
labels = sorted(d); base = st.mean(d[labels[0]])
for l in labels:
    x = sorted(d[l])
    print('WALL %-14s n=%d  min %5d  median %5d  mean %7.1f  max %5d ms   (mean %+6.1f ms, %+5.1f %% vs %s)' % (l, len(x), x[0], st.median(x), st.mean(x), x[-1], st.mean(x) - base, 100 * (st.mean(x) - base) / base, labels[0]))
PY
