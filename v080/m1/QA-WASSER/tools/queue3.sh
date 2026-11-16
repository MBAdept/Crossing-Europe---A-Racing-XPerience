#!/usr/bin/env bash
# QA-WASSER queue 3 (one Godot job at a time): mutations of the unit test, the Arcade identity gate, the terrain
# cover render check, old/new baseline pictures, PCK reproducibility.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-2
T=$S/tools
mkdir -p "$S/gates"
cd "$W" || exit 1
only=${1:-mutate,golden,render,baseline,repro}
has() { [[ ",$only," == *",$1,"* ]]; }
if has mutate; then
	echo "== mutate $(date +%T)"
	"$T/mutate_all.sh" > "$S/gates/mutate.log" 2>&1
	grep -E "^== |Tests bestanden|bestanden|fehlgeschlagen|FEHL|^ M|^\?\?" "$S/gates/mutate.log" | head -40
fi
git checkout -- scripts/race3d/layers/far_ground.gd
git status --short
if has golden; then
	echo "== golden check $(date +%T)"
	t0=$SECONDS
	XDG_DATA_HOME=$S/xdg/golden nice -n 5 tools/golden.sh check > "$S/gates/golden_check.log" 2>&1
	echo "golden check exit $? ($((SECONDS - t0)) s)"
	grep -E "GOLDEN" "$S/gates/golden_check.log"
fi
if has render; then
	echo "== render terrain_cover $(date +%T)"
	t0=$SECONDS
	mkdir -p "$S/xdg/render"
	XDG_DATA_HOME=$S/xdg/render nice -n 5 tools/run_render_checks.sh modern terrain_cover > "$S/gates/render_terrain_cover.log" 2>&1
	echo "render terrain_cover exit $? ($((SECONDS - t0)) s)"
	grep -E "RENDER-CHECK" "$S/gates/render_terrain_cover.log" | head -20
fi
if has baseline; then
	echo "== baseline $(date +%T)"
	"$T/baseline.sh" > "$S/gates/baseline.log" 2>&1
	cat "$S/gates/baseline.log"
fi
git checkout -- scripts/race3d/layers/far_ground.gd
git status --short
if has repro; then
	echo "== repro $(date +%T)"
	"$T/repro.sh" > "$S/gates/repro.log" 2>&1
	cat "$S/gates/repro.log"
fi
echo "== fertig $(date +%T)"
