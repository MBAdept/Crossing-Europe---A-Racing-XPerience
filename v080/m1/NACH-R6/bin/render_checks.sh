#!/usr/bin/env bash
# NACH-R6: the render checks that belong to the changed files and the first-test-build fixes, one file at a time.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4
cd "$W" || exit 1
export XDG_DATA_HOME=$S/xdg_rc
export MESA_SHADER_CACHE_DIR=$S/mesa
export RENDER_CHECK_TIMEOUT=2400
mkdir -p "$XDG_DATA_HOME"
for f in ${*:-check_structures.gd check_structures_licht.gd check_start_km0 check_terrain_cover check_light_base}; do
	t0=$(date +%s)
	nice -n 10 tools/run_render_checks.sh modern "$f" > "$S/logs/rc_$f.log" 2>&1
	echo "$f exit $? $(( $(date +%s) - t0 )) s"
	grep -E "RENDER-CHECK" "$S/logs/rc_$f.log" | cut -c1-300
done
