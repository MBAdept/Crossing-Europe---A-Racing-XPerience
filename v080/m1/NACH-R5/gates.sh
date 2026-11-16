#!/usr/bin/env bash
# NACH-R5 gates, one after the other: gates.sh [step…]  (steps: scripts units render full golden)
set -uo pipefail
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-8
G=$N/gates
mkdir -p "$G" "$N/xdg_gates" "$N/mesa" "$N/tmp"
export XDG_DATA_HOME=$N/xdg_gates
export MESA_SHADER_CACHE_DIR=$N/mesa
export TMPDIR=$N/tmp
WANT=" $* "
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
cd "$WT" || exit 1
run() {   # run <name> <cmd…>
	local name=$1; shift
	local t0=$SECONDS
	nice -n 10 "$@" > "$G/$name.log" 2>&1
	local rc=$?
	echo "== $name exit $rc $((SECONDS - t0)) s | script errors $(grep -cE 'SCRIPT ERROR|SHADER ERROR|Parse Error' "$G/$name.log")"
}
if want scripts; then run check_scripts timeout 900 godot --headless --path . -s res://tests/check_scripts.gd; tail -2 "$G/check_scripts.log"; fi
if want units; then
	for f in test_tunnel test_bridge test_far_ground_water test_props; do
		run "unit_$f" timeout 1800 tools/run_tests.sh "$f"
		grep -E "Tests,|==>|FAIL" "$G/unit_$f.log" | tail -5
	done
fi
if want render; then
	for f in tunnel_bridge terrain_cover start_km0 light_base; do
		RENDER_CHECK_TIMEOUT=1800 run "render_$f" tools/run_render_checks.sh modern "$f"
		grep -E "RENDER-CHECK|DATEI" "$G/render_$f.log" | tail -14
	done
fi
if want full; then
	run scan_full timeout 1800 godot --headless --path . -s res://tests/race3d/render/check_tunnel_bridge.gd -- --full
	grep -E "RENDER-CHECK|MANGEL" "$G/scan_full.log" | tail -8
fi
if want golden; then
	run golden_check tools/golden.sh check
	grep -E "GOLDEN" "$G/golden_check.log" | tail -4
fi
echo "GATES_DONE $*"
