#!/bin/bash
# QA-BILD queue part 2b: after "queue end" - render checks (all Modern + saved pictures), golden check.
# run_tests.sh is left out (QA-SYSTEM ran it at the same head; time).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-2
Q=$S/queue.log
log() { echo "$(date +%H:%M:%S) $*" >> $Q; }
until grep -q "queue end" $Q 2>/dev/null; do sleep 15; done
log "queue2b start"
cd $WT || exit 1
mkdir -p $S/rc $S/rc/save $S/xdg_rc
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
export LP_NUM_THREADS=2
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_rc nice -n 10 tools/golden.sh check > $S/rc/golden.log 2>&1
log "golden check exit=$? $((SECONDS - t0)) s"
for f in check_vehicle_lights check_occlusion check_vehicle_standin; do
	t0=$SECONDS
	XDG_DATA_HOME=$S/xdg_rc nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --fixed-fps 60 -s res://tests/race3d/render/$f.gd -- --graphics=modern --gfx-sync --audio-sync \
		--save=$S/rc/save > $S/rc/$f.save.log 2>&1
	log "$f --save exit=$? $((SECONDS - t0)) s"
done
for flt in terrain_cover road_parity light_base; do
	t0=$SECONDS
	XDG_DATA_HOME=$S/xdg_rc nice -n 10 tools/run_render_checks.sh modern $flt > $S/rc/render_$flt.log 2>&1
	log "render check $flt exit=$? $((SECONDS - t0)) s"
done
log "queue2 end"
