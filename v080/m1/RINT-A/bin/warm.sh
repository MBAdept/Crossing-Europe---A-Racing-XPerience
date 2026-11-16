#!/bin/bash
# Cold-cache warm-up check (tests/race3d/render/warmup_cold.gd) with an EMPTY user folder and Mesa cache:
#   warm.sh <name> [args]  -> $S/logs/warm_<name>.log
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
name=$1; shift
cold="$S/cold_$name"
rm -rf "$cold"
mkdir -p "$cold/xdg" "$cold/mesa"
start=$(date +%s)
MESA_SHADER_CACHE_DIR="$cold/mesa" XDG_DATA_HOME="$cold/xdg" nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" \
	godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tests/race3d/render/warmup_cold.gd \
	-- --graphics=modern "$@" > "$S/logs/warm_$name.log" 2>&1
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s  (log $S/logs/warm_$name.log); load $(cut -d' ' -f1-3 /proc/loadavg)"
grep -E "RENDER-CHECK|SCRIPT ERROR|SHADER ERROR" "$S/logs/warm_$name.log" | head -10
echo "mesa cache files: $(find "$cold/mesa" -type f | wc -l)"
rm -rf "$cold"
