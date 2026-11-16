#!/usr/bin/env bash
# NACH-R6: unit tests that belong to the changed files, one after another (nice 10)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4
cd "$W" || exit 1
export XDG_DATA_HOME=$S/xdg_unit
mkdir -p "$XDG_DATA_HOME"
for f in test_structures test_props test_far_ground_water check_minimal_structures; do
	t0=$(date +%s)
	nice -n 10 tools/run_tests.sh "$f" > "$S/logs/unit_$f.log" 2>&1
	echo "$f exit $? $(( $(date +%s) - t0 )) s"
	tail -4 "$S/logs/unit_$f.log"
done
