#!/bin/bash
# K1 (Köhlbrandbrücke km 78.1) of check_terrain_cover: with the fix, then with the old far_ground.gd (3a23cb8) – the
# gate must turn red there. Restores far_ground.gd at the end.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-3
export XDG_DATA_HOME=$S/xdg_render
export MESA_SHADER_CACHE_DIR=$S/xdg_render/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$W" || exit 1
run() {
	nice -n 5 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 -s res://tests/race3d/render/check_terrain_cover.gd -- --graphics=modern --gfx-sync \
		--audio-sync --only=K1 --save="$1" 2>&1 | grep -E 'RENDER-CHECK|SCRIPT ERROR|Parse Error'
}
echo "== mit Fix (HEAD)"
run "$S/k1/neu"
echo "== alter far_ground.gd (3a23cb8)"
git show 3a23cb8:scripts/race3d/layers/far_ground.gd > scripts/race3d/layers/far_ground.gd
run "$S/k1/alt"
git checkout HEAD -- scripts/race3d/layers/far_ground.gd
git status --short
echo "== done"
