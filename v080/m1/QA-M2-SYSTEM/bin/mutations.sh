#!/bin/bash
# Do the tests changed by the merge still guard their rule? One line of production code broken per rule in the
# SCRATCH COPY $S/mut, the guarding test run, then the line restored (from the gate worktree). Baselines first
# (unmutated copy): the same tests must pass there.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
M=$S/mut
OUT=$S/mutations
mkdir -p "$OUT"
X=$S/xdg_mut; mkdir -p "$X"
cd "$M" || exit 2
vehicles() { # tag only
	XDG_DATA_HOME=$X nice -n 10 timeout 1200 godot --headless --path . -s res://tests/race3d/check_vehicles.gd -- --only="$2" > "$OUT/$1.log" 2>&1
	local code=$?
	echo "  $1: exit=$code  $(grep -E '^CHECK ' "$OUT/$1.log" | cut -c1-200 | tr '\n' ' ')"
}
props() { # tag [filter]
	XDG_DATA_HOME=$X nice -n 10 timeout 1200 godot --headless --path . -s res://tests/run_tests.gd -- --filter=${2:-test_props} > "$OUT/$1.log" 2>&1
	local code=$?
	echo "  $1: exit=$code  $(grep -E 'Tests, ' "$OUT/$1.log" | tail -1)  rot: $(grep -E '^FAIL|^not ok|FEHL' "$OUT/$1.log" | cut -c1-150 | head -4 | tr '\n' ' ')"
}
mut() { python3 "$S/bin/mutate.py" "$M" "$1" "$2"; }
WHAT=${WHAT:-"base vehicles props"}
for w in $WHAT; do
	case $w in
	base)
		echo "== Grundlinie (unverändert)"
		vehicles base_vehicles kasten,leistung
		props base_props ;;
	vehicles)
		for m in kasten_box kasten_sprite; do
			echo "== $m"; mut "$m" apply; vehicles "mut_$m" kasten; mut "$m" revert
		done
		for m in leistung_cache leistung_trim; do
			echo "== $m"; mut "$m" apply; vehicles "mut_$m" leistung; mut "$m" revert
		done ;;
	props)
		for m in props_pylon_albedo props_pylon_emit props_landmark props_blink props_standin_dark; do
			echo "== $m"; mut "$m" apply; props "mut_$m"; mut "$m" revert
		done ;;
	terrain)
		echo "== Grundlinie Gelände/Fernboden"
		props base_terrain test_terrain_builder
		props base_farwater test_far_ground_water
		echo "== farground_water"; mut farground_water apply
		props mut_farground_water_tb test_terrain_builder
		props mut_farground_water_fw test_far_ground_water
		mut farground_water revert ;;
	golden)
		echo "== Modern-Änderungsmelder: Grundlinie S3, dann golden_road"
		( XDG_DATA_HOME=$X GLES_ID= KEEP=$OUT/golden_base tools/golden.sh modern-check s3 ) > "$OUT/golden_base.log" 2>&1
		echo "  base: exit=$? $(grep -E 'GOLDEN' "$OUT/golden_base.log" | tr '\n' ' ')"
		mut golden_road apply
		( XDG_DATA_HOME=$X GLES_ID= KEEP=$OUT/golden_mut tools/golden.sh modern-check s3 ) > "$OUT/golden_mut.log" 2>&1
		echo "  mut: exit=$? $(grep -E 'GOLDEN' "$OUT/golden_mut.log" | tr '\n' ' ')"
		mut golden_road revert ;;
	esac
done
echo "-- Kopie gegen den Arbeitsbaum (nur override.cfg darf abweichen):"
for f in scripts/race3d/layers/vehicles.gd scripts/race3d/builders/props.gd scripts/race3d/layers/flares.gd scripts/race3d/layers/far_ground.gd assets/shaders/modern/road.gdshader; do
	cmp -s "$M/$f" "$WT/$f" && echo "  $f = Arbeitsbaum" || echo "  $f WEICHT AB"
done
echo ALLDONE
