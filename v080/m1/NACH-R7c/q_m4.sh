#!/bin/bash
# NACH-R7c: the 4-way merge probe as a tree (m4): export + import, compile check, test_props / test_far_ground_water /
# test_chunk_streamer / test_sight_corridor (the files the merge touches around props.gd).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c
bash "$S/merge_tree_export.sh" export > "$S/logs/m4_export.out" 2>&1
cd "$S/m4" || exit 1
export XDG_DATA_HOME=$S/xdg_gate
nice -n 10 timeout 900 godot --headless --path . -s res://tests/check_scripts.gd > "$S/gates/m4_check_scripts.log" 2>&1
echo "$(date -u +%H:%M:%S) m4 check_scripts exit=$?" >> "$S/logs/q.out"
for t in test_props test_far_ground_water test_chunk_streamer test_sight_corridor; do
	nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- --filter=$t > "$S/gates/m4_unit_$t.log" 2>&1
	echo "$(date -u +%H:%M:%S) m4 unit $t exit=$?" >> "$S/logs/q.out"
done
echo "M4 DONE $(date -u +%H:%M:%S)" >> "$S/logs/q.out"
