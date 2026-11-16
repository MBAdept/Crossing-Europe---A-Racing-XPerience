#!/bin/bash
# bench.sh <tag> <tree> <preset…> – Leistungstest (all scenes) per preset under Xvfb, results in bench/<tag>_<preset>.json
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
TAG=$1
TREE=$2
shift 2
N=${NICE:-19}
SECS=${BENCH_S:-10}
mkdir -p "$R4/bench"
cd "$TREE" || exit 2
for P in "$@"; do
	rm -rf "$R4/bench/xdg_$TAG"
	mkdir -p "$R4/bench/xdg_$TAG"
	T0=$(date +%s)
	XDG_DATA_HOME=$R4/bench/xdg_$TAG MESA_SHADER_CACHE_DIR=$R4/mesa_bench_$TAG nice -n $N timeout 2400 \
		xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 -- --graphics=modern --gfx-preset=$P --bench=all --bench-seconds=$SECS \
		--bench-out=$R4/bench/${TAG}_$P.json > "$R4/bench/${TAG}_$P.log" 2>&1
	echo "exit=$? wall=$(( $(date +%s) - T0 ))" >> "$R4/bench/${TAG}_$P.log"
	grep -a "SCRIPT ERROR\|SHADER ERROR" "$R4/bench/${TAG}_$P.log" | head -3
	echo "$TAG $P $(tail -1 "$R4/bench/${TAG}_$P.log")"
done
rm -rf "$R4/bench/xdg_$TAG"
