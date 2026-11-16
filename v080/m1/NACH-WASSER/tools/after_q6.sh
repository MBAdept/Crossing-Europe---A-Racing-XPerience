#!/usr/bin/env bash
# NACH-WASSER: after queue 6 – the terrain render check with the new position K1 (B5) on 39849f0, one job.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-4
until grep -q "^== fertig" "$S/logs/queue6.log" 2>/dev/null; do sleep 5; done
mkdir -p "$S/xdg/render" "$S/tmp_render" "$S/mesa_render"
t0=$SECONDS
(cd "$W" && XDG_DATA_HOME="$S/xdg/render" TMPDIR="$S/tmp_render" MESA_SHADER_CACHE_DIR="$S/mesa_render" nice -n 10 \
	tools/run_render_checks.sh modern terrain_cover) > "$S/logs/render_terrain_cover.log" 2>&1
echo "== terrain_cover exit $? ($((SECONDS - t0)) s) $(date -u +%T)"
