#!/bin/bash
# warmup_cold.gd with an empty user folder and Mesa cache, Mesa dumping every shader source it is given:
#   warmdump.sh <name> [args]  -> $S/warmdump_<name>/{dump,mesa} + $S/logs/warmdump_<name>.log (folders are kept)
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
name=$1; shift
cold="$S/warmdump_$name"
rm -rf "$cold"
mkdir -p "$cold/xdg" "$cold/mesa" "$cold/dump"
start=$(date +%s)
MESA_SHADER_DUMP_PATH="$cold/dump" MESA_SHADER_CACHE_DIR="$cold/mesa" XDG_DATA_HOME="$cold/xdg" nice -n 10 timeout 1500 \
	xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tests/race3d/render/warmup_cold.gd -- --graphics=modern "$@" > "$S/logs/warmdump_$name.log" 2>&1
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s; load $(cut -d' ' -f1-3 /proc/loadavg)"
grep -E "RENDER-CHECK|SCRIPT ERROR|SHADER ERROR" "$S/logs/warmdump_$name.log" | cut -c1-400 | head -5
echo "mesa cache files: $(find "$cold/mesa" -type f | wc -l); dumped sources: $(find "$cold/dump" -type f | wc -l)"
echo "--- last 6 cache files:"
find "$cold/mesa" -type f -printf '%T@ %p\n' | sort -n | tail -6 | awk '{printf "%.2f %s\n", $1, $2}'
echo "--- last 12 dumped sources:"
find "$cold/dump" -type f -printf '%T@ %p\n' | sort -n | tail -12 | awk '{printf "%.2f %s\n", $1, $2}'
