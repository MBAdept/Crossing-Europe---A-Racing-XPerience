#!/bin/bash
# NACH-R7c queue: compile check, baseline unit tests on the clean head, then the mutations (mutate.py).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-12
mkdir -p "$S/gates" "$S/xdg_gate"
export XDG_DATA_HOME=$S/xdg_gate
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
cd "$WT" || exit 1
if ! grep -q "geprüft" "$S/gates/check_scripts.log" 2>/dev/null; then
	nice -n 10 timeout 900 godot --headless --path . -s res://tests/check_scripts.gd > "$S/gates/check_scripts.log" 2>&1
	echo "$(date -u +%H:%M:%S) check_scripts exit=$?" >> "$S/logs/q.out"
fi
for t in test_props test_far_ground_water; do
	if ! grep -q "fehlgeschlagen" "$S/gates/unit_$t.log" 2>/dev/null; then
		nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- --filter=$t > "$S/gates/unit_$t.log" 2>&1
		echo "$(date -u +%H:%M:%S) unit $t exit=$?" >> "$S/logs/q.out"
	fi
done
python3 "$S/mutate.py" >> "$S/logs/q.out" 2>&1
echo "Q MUT DONE $(date -u +%H:%M:%S)" >> "$S/logs/q.out"
