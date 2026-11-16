#!/usr/bin/env bash
# Experiment (never committed): clamp the inside ribbon by the sharpest curvature of the cross-section's side within
# the kernel's own window (kap.x / kap.y of TerrainProfile._kappa), run the plan check and the sight check, revert.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-2
R2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R2
cd "$WT" || exit 1
cp scripts/race3d/terrain_profile.gd "$R2/terrain_profile.backup.gd"
python3 - <<'EOF'
p='scripts/race3d/terrain_profile.gd'
s=open(p).read()
old='''		if k_in > 1.0e-6:
			lim = minf(lim, inside_bend_factor / k_in - e)'''
new='''		if k_in > 1.0e-6:
			lim = minf(lim, inside_bend_factor / k_in - e)
		var k_near := kap.x if si == 0 else kap.y
		if k_near > 1.0e-6:
			lim = minf(lim, inside_bend_factor / k_near - e)'''
assert old in s, "pattern not found"
open(p,'w').write(s.replace(old,new))
EOF
export XDG_DATA_HOME=$R2/xdg
timeout 600 nice -n 10 godot --headless --path . -s res://tests/race3d/check_terrain_plan.gd 2>&1 | grep -E "CHECK|==>"
timeout 600 nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd 2>&1 | grep -E "CHECK|==>"
cp "$R2/terrain_profile.backup.gd" scripts/race3d/terrain_profile.gd
git diff --quiet -- scripts/race3d/terrain_profile.gd && echo "reverted (git diff empty)"
