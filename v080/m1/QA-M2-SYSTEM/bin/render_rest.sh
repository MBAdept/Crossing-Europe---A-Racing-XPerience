#!/bin/bash
# The Modern render checks that the first run (run_render_checks.sh all, outer nice + the script's nice = 19) did not
# reach, each through tools/run_render_checks.sh modern <file stem> (the script's own nice 10, same XDG_DATA_HOME and
# Mesa cache as the first run); the forest check last with RENDER_CHECK_TIMEOUT=3000 (it timed out at 900 s under load).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
cd "$WT" || exit 2
export XDG_DATA_HOME=$S/xdg_rc
FILES=${FILES:-"check_light_base check_models check_modern_render check_occlusion check_props_render check_quit_sound check_road_parity check_seam_render check_session_modern check_showroom_render check_start_km0 check_terrain_cover check_vehicle_lights check_vehicle_standin"}
for f in $FILES; do
	t0=$SECONDS
	tools/run_render_checks.sh modern "$f" 2>&1 | grep -vE "^==> [0-9]+ von"
	echo "  ($f: $((SECONDS - t0)) s, Last $(cut -d' ' -f1 /proc/loadavg))"
done
if [ -z "${NO_WALD:-}" ]; then
	t0=$SECONDS
	RENDER_CHECK_TIMEOUT=3000 tools/run_render_checks.sh modern check_instance_budget_wald 2>&1 | grep -vE "^==> [0-9]+ von"
	echo "  (wald: $((SECONDS - t0)) s, Last $(cut -d' ' -f1 /proc/loadavg))"
fi
echo ALLDONE
