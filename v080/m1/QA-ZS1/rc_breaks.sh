#!/usr/bin/env bash
# QA-ZS1: is tests/race3d/render/check_start_km0.gd a real guard? Runs it on the clean tree (through
# tools/run_render_checks.sh, as the gates do), then directly with three deliberate breaks of the fix, each restored
# from git afterwards:
#   A  layers/vehicles.gd: z_lo back to the first boundary (the player's car hidden in the countdown)
#   B  road_path.gd: no lead-in in _locate() (the camera clamps to z = 0 again – 9 m too far ahead)
#   C  chunk_streamer.gd: no chunk -1 (camera and car right, but no road / ground before the start line)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-2
cd "$W" || exit 2
export XDG_DATA_HOME=$S/xdg_rc
export MESA_SHADER_CACHE_DIR=$S/mesa_rc
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR" "$S/rc"
echo "== clean (runner) $(date -u +%T)"
tools/run_render_checks.sh modern start_km0 2>&1 | tee "$S/rc/clean_runner.log"
echo "exit ${PIPESTATUS[0]}"

run_direct() {
	local name=$1
	local t0=$SECONDS
	nice -n 5 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 -s res://tests/race3d/render/check_start_km0.gd -- --graphics=modern --gfx-sync \
		--audio-sync "--save=$S/rc/$name" > "$S/rc/$name.log" 2>&1
	local code=$?
	echo "== $name: exit $code ($((SECONDS - t0)) s)"
	grep -E "^RENDER-CHECK|^  (countdown|los)|SCRIPT ERROR|Parse Error" "$S/rc/$name.log"
}

# A
sed -i 's/	var z_lo := path.z_min()/	var z_lo := float(path.first) * path.seg_len/' scripts/race3d/layers/vehicles.gd
git diff --stat
run_direct break_A_vehicles
git checkout -- scripts/race3d/layers/vehicles.gd
# B
sed -i 's/	_lb = z if z < 0.0 and first == 0 else 0.0 .*/	_lb = 0.0/' scripts/race3d/road_path.gd
git diff --stat
run_direct break_B_camera
git checkout -- scripts/race3d/road_path.gd
# C
sed -i 's/	var c_min := -1 if path.has_lead_in() else int(ceil(float(path.first) \/ float(n)))/	var c_min := int(ceil(float(path.first) \/ float(n)))/' scripts/race3d/chunk_streamer.gd
git diff --stat
run_direct break_C_no_chunk
git checkout -- scripts/race3d/chunk_streamer.gd
echo "== restored:"
git status --short
echo RCDONE
