#!/bin/bash
# QA1 queue 2: after queue1 (bench done): S5 again + deck pictures, then a trial of check_modern_render.gd.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
Q=$S/queue2.log
log() { echo "$(date +%H:%M:%S) $*" >> "$Q"; }
log "queue2 start"
until grep -q "queue end" "$S/queue1.log" 2>/dev/null; do sleep 15; done
log "queue1 finished"
"$S/run_s5.sh" >> "$Q" 2>&1
log "s5 + deck done"
cd "$WT" || exit 1
X=$S/xdg_rc_trial
rm -rf "$X" "$S/rc_trial"
mkdir -p "$X" "$S/rc_trial"
export MESA_SHADER_CACHE_DIR=$S/mesa_rc
mkdir -p "$MESA_SHADER_CACHE_DIR"
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s res://tests/race3d/render/check_modern_render.gd -- \
	--graphics=modern --gfx-sync --audio-sync --save="$S/rc_trial" > "$S/rc_trial.log" 2>&1
log "check_modern_render exit=$? $((SECONDS - t0)) s"
grep -E "^RENDER-CHECK|SCRIPT ERROR|SHADER ERROR|^ERROR" "$S/rc_trial.log" >> "$Q"
log "queue2 end"
