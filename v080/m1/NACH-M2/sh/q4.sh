#!/bin/bash
# NACH-M2 queue 4 (after q3): Modern change detector check of the committed list, then a mutation run of the two new
# vehicle-light checks (old SPOT_SPECULAR 0.6 and no model glow gains) – the worktree is restored afterwards.
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-M2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-6
L=$N/logs/q4.log
while ! grep -q Q3-DONE $N/logs/q3.log 2>/dev/null; do sleep 20; done
export MESA_SHADER_CACHE_DIR=$N/mesa
export LP_NUM_THREADS=2
cd "$WT" || exit 1
G=$N/logs/gate_modern_check.log
if ! grep -q "^STEP-END" "$G" 2>/dev/null; then
	echo "$(date -u +%T) start modern_check" >> $L
	t0=$SECONDS
	X=$N/xdg/mc; rm -rf "$X"; mkdir -p "$X"
	XDG_DATA_HOME=$X KEEP=$N/modern_keep nice -n 10 tools/golden.sh modern-check > "$G" 2>&1
	echo "STEP-END exit=$? $((SECONDS - t0)) s" >> "$G"
	rm -rf "$X"
	echo "$(date -u +%T) end modern_check" >> $L
fi
G=$N/logs/gate_mutation.log
if ! grep -q "^STEP-END" "$G" 2>/dev/null; then
	echo "$(date -u +%T) start mutation" >> $L
	sed -i 's/^const SPOT_SPECULAR := 0.0/const SPOT_SPECULAR := 0.6/' scripts/race3d/layers/lights.gd
	sed -i 's/^const MODEL_BRAKE_GAIN := 2.2/const MODEL_BRAKE_GAIN := 1.0/; s/^const MODEL_BEACON_GAIN := 2.4/const MODEL_BEACON_GAIN := 1.0/' scripts/race3d/vehicle_pose3d.gd
	git diff --stat > "$G" 2>&1
	t0=$SECONDS
	X=$N/xdg/mut; rm -rf "$X"; mkdir -p "$X"
	XDG_DATA_HOME=$X nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s res://tests/race3d/render/check_vehicle_lights.gd -- \
		--graphics=modern --gfx-sync --audio-sync --only=blaulicht,abblendlicht >> "$G" 2>&1
	code=$?
	git checkout -- scripts/race3d/layers/lights.gd scripts/race3d/vehicle_pose3d.gd
	echo "after restore:" >> "$G"
	git status --short >> "$G" 2>&1
	echo "STEP-END exit=$code $((SECONDS - t0)) s" >> "$G"
	rm -rf "$X"
	echo "$(date -u +%T) end mutation exit=$code" >> $L
fi
echo "$(date -u +%T) Q4-DONE" >> $L
