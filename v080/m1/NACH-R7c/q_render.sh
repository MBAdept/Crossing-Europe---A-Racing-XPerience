#!/bin/bash
# NACH-R7c: render checks that belong to the changed files and the first-test-build guards, one after the other.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-12
mkdir -p "$S/gates" "$S/xdg_render"
export XDG_DATA_HOME=$S/xdg_render
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
cd "$WT" || exit 1
for f in check_lod_band check_start_km0 check_terrain_cover check_light_base check_weather.gd check_props_render check_session_modern check_instance_budget.gd; do
	log="$S/gates/render_${f%.gd}.log"
	if grep -q "RENDER-CHECK-DATEI" "$log" 2>/dev/null; then continue; fi
	while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
	t0=$SECONDS
	nice -n 10 tools/run_render_checks.sh modern "$f" > "$log" 2>&1
	echo "$(date -u +%H:%M:%S) $f exit=$? $((SECONDS - t0)) s" >> "$S/logs/render.out"
done
echo "RENDER DONE $(date -u +%H:%M:%S)" >> "$S/logs/render.out"
