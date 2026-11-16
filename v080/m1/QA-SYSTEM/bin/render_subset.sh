#!/bin/bash
# The render checks of the system lens (Xvfb): quitting with both sound profiles, the seam with a real renderer,
# the Modern session, the showroom, the instance budget of the global shader buffer; plus the Arcade render checks.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
export XDG_DATA_HOME=$S/xdg_render
mkdir -p "$XDG_DATA_HOME"
export MESA_SHADER_CACHE_DIR=$S/mesa_render
cd "$WT" || exit 2
for f in quit_sound seam_render session_modern showroom instance_budget; do
	t0=$SECONDS
	nice -n 10 tools/run_render_checks.sh modern "$f" > "$S/render_$f.log" 2>&1
	echo "modern $f exit=$? $((SECONDS - t0)) s"
	grep -E "RENDER-CHECK" "$S/render_$f.log" | cut -c1-220
done
t0=$SECONDS
nice -n 10 tools/run_render_checks.sh arcade > "$S/render_arcade.log" 2>&1
echo "arcade exit=$? $((SECONDS - t0)) s"
grep -E "RENDER-CHECK-DATEI|GLOW-CHECK|FLIP-CHECK" "$S/render_arcade.log" | cut -c1-200 | head -20
echo ALLDONE
