#!/usr/bin/env bash
# AS2b final gates, one heavy job after the other (nice 19):
#   1 determinism: forced export + bake of police/* and traffic/bus (the trucks were identical in run 1), git status
#   2 check_sprite_geometry for the heavy and police sets (one worker)
#   3 tools/run_tests.sh (the one run at the end)
#   4 tools/golden.sh check (the one run at the end)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2b
L=$S/logs
cd "$WT"
export XDG_DATA_HOME=$S/xdg
echo "== 1 determinism ($(date +%T))"
for g in "police/*" "traffic/bus" "traffic/truck*"; do
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$g" --jobs=1 --force > "$L/gate_export.log" 2>&1
	echo "export $g exit $?"
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" > "$L/gate_bake.log" 2>&1
	echo "bake $g exit $?"
done
python3 tools/blender/export_models.py --manifest-only | tail -1
echo "git status (empty = identical):"
git status --short
echo "== 2 check_sprite_geometry ($(date +%T))"
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only traffic/truck,traffic/bus,police --jobs 1 > "$L/gate_geometry.log" 2>&1
echo "geometry exit $?"
tail -4 "$L/gate_geometry.log"
echo "== 3 run_tests ($(date +%T))"
rm -rf "$S/xdg_tests" && mkdir -p "$S/xdg_tests"
XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh > "$L/gate_tests.log" 2>&1
echo "tests exit $?"
grep -E "^CHECK .*FEHLER|fehlgeschlagen|==> Tests|FAIL|SCRIPT ERROR" "$L/gate_tests.log" | head -40
echo "== 4 golden ($(date +%T))"
nice -n 19 tools/golden.sh check > "$L/gate_golden.log" 2>&1
echo "golden exit $?"
grep -E "GOLDEN|identisch|abweich|Umgebung" "$L/gate_golden.log" | tail -5
echo "gates.sh fertig ($(date +%T))"
