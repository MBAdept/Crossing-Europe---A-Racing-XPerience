#!/bin/bash
# R7a: the remaining gates on the final head, one heavy job at a time.
#   render checks: the Modern files not yet run (rc_subset.log has terrain_cover, start_km0, light_base,
#   props_render, structures*), then the Arcade render checks; golden modern-check; modern_sight --full;
#   modern_path_check --full.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export TMPDIR=$S/tmp
mkdir -p "$S/rc" "$S/xdg/rc" "$S/xdg/gates" "$S/mesa"
echo "$(date -u +%H:%M:%S) start $(cd "$WT" && git rev-parse --short HEAD)"
for f in facade_render instance_budget models modern_render night occlusion quit_sound road_parity seam_render \
	session_modern showroom_render tunnel_bridge vehicle_lights vehicle_standin weather; do
	while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
	t0=$SECONDS
	(cd "$WT" && XDG_DATA_HOME=$S/xdg/rc nice -n 10 tools/run_render_checks.sh modern "$f" > "$S/rc/$f.log" 2>&1)
	echo "$(date -u +%H:%M:%S) rc $f exit=$? $((SECONDS - t0)) s: $(grep -E 'RENDER-CHECK-DATEI' "$S/rc/$f.log" | tr -s ' ' | tr '\n' ' ')"
done
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$S/xdg/rc nice -n 10 tools/run_render_checks.sh arcade > "$S/rc/arcade.log" 2>&1)
echo "$(date -u +%H:%M:%S) rc arcade exit=$? $((SECONDS - t0)) s: $(grep -E 'RENDER-CHECK-DATEI' "$S/rc/arcade.log" | tr -s ' ' | tr '\n' ' ')"
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$S/xdg/gates MESA_SHADER_CACHE_DIR=$S/mesa nice -n 10 tools/golden.sh modern-check > "$S/golden_modern_check.log" 2>&1)
echo "$(date -u +%H:%M:%S) golden modern-check exit=$? $((SECONDS - t0)) s: $(grep -a 'GOLDEN' "$S/golden_modern_check.log" | tail -2 | tr '\n' ' ')"
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$S/xdg/gates nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$S/sight_full.log" 2>&1)
echo "$(date -u +%H:%M:%S) modern_sight --full exit=$? $((SECONDS - t0)) s"
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$S/xdg/gates nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$S/path_full.log" 2>&1)
echo "$(date -u +%H:%M:%S) modern_path_check --full exit=$? $((SECONDS - t0)) s"
echo "$(date -u +%H:%M:%S) done"
