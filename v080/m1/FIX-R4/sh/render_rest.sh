#!/bin/bash
# render_rest.sh – the Modern render checks that the first "run_render_checks.sh all" did not reach (its parent was
# stopped by the tool's time limit after check_instance_budget.gd), one file per call, then GATES_DONE for post.sh
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5
G=$S/gates
cd $WT || exit 2
echo "== render_rest start $(date -u +%T)" >> $G/gates.log
for f in check_instance_budget_wald.gd check_light_base.gd check_models.gd check_modern_render.gd check_night.gd \
	check_night_nass.gd check_occlusion.gd check_props_render.gd check_quit_sound.gd check_road_parity.gd \
	check_seam_render.gd check_session_modern.gd check_showroom_render.gd check_start_km0.gd check_terrain_cover.gd \
	check_vehicle_lights.gd check_vehicle_standin.gd check_weather.gd check_weather_tabelle.gd \
	check_weather_tabelle_schnee.gd; do
	XDG_DATA_HOME=$S/xdg/render MESA_SHADER_CACHE_DIR=$S/mesa_render RENDER_CHECK_TIMEOUT=2700 nice -n 10 \
		tools/run_render_checks.sh modern "$f" >> $G/render2.log 2>&1
	echo "   $f exit=$? $(date -u +%T)" >> $G/gates.log
done
echo "== render_rest done $(date -u +%T)" >> $G/gates.log
echo GATES_DONE >> $G/gates.log
