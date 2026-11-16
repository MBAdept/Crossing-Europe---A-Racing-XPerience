#!/bin/bash
# Follow-ups of the mutation step (in the scratch copy $S/mut, one at a time):
#  golden_lane      the Modern change detector with an effective picture change (lane lines 20 % wider)
#  leistung_cache   does check_vehicles "instanzen" catch the lost level cache that "leistung" missed?
#  props_gate       props_pylon_albedo through tools/run_tests.sh (the gate: does its SCRIPT ERROR grep turn it red?)
#  farground_nums   the numbers of test_far_ground_lies_below_the_water_of_a_bridge (plane, water) with and without
#                   the water term
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
M=$S/mut
OUT=$S/mutations
X=$S/xdg_mut; mkdir -p "$X"
cd "$M" || exit 2
mut() { python3 "$S/bin/mutate.py" "$M" "$1" "$2"; }
WHAT=${WHAT:-"golden_lane leistung_cache props_gate"}
for w in $WHAT; do
	case $w in
	golden_lane)
		mut golden_lane apply
		( XDG_DATA_HOME=$X GLES_ID= KEEP=$OUT/golden_lane tools/golden.sh modern-check s3 ) > "$OUT/golden_lane.log" 2>&1
		echo "golden_lane: exit=$? $(grep -E 'GOLDEN' "$OUT/golden_lane.log" | tr '\n' ' ')"
		mut golden_lane revert ;;
	leistung_cache)
		mut leistung_cache apply
		XDG_DATA_HOME=$X nice -n 10 timeout 1800 godot --headless --path . -s res://tests/race3d/check_vehicles.gd -- --only=instanzen > "$OUT/mut_leistung_cache_instanzen.log" 2>&1
		echo "leistung_cache/instanzen: exit=$? $(grep -E '^CHECK ' "$OUT/mut_leistung_cache_instanzen.log" | cut -c1-300 | tr '\n' ' ')"
		mut leistung_cache revert ;;
	props_gate)
		mut props_pylon_albedo apply
		( XDG_DATA_HOME=$X nice -n 10 tools/run_tests.sh test_props ) > "$OUT/props_gate.log" 2>&1
		echo "props_gate: exit=$? $(grep -E 'Tests bestanden|FEHLGESCHLAGEN|Skriptfehler|Tests, ' "$OUT/props_gate.log" | tr '\n' ' ')"
		mut props_pylon_albedo revert ;;
	esac
done
for f in scripts/race3d/layers/vehicles.gd scripts/race3d/builders/props.gd scripts/race3d/builders/road.gd; do
	cmp -s "$M/$f" "$WT/$f" && echo "  $f = Arbeitsbaum" || echo "  $f WEICHT AB"
done
echo ALLDONE
