#!/usr/bin/env bash
# QA-WASSER: run the unit test test_far_ground_water against mutations of far_ground.gd (restored afterwards).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-2
F=scripts/race3d/layers/far_ground.gd
cd "$W" || exit 1
export XDG_DATA_HOME=$S/xdg/mutate
mkdir -p "$XDG_DATA_HOME" "$S/mutate"
for m in ${1:-M0 M1 M2 M3 M4}; do
	git checkout -- "$F"
	python3 -I "$S/tools/mutate.py" "$F" "$m" || continue
	t0=$SECONDS
	nice -n 5 tools/run_tests.sh test_far_ground_water > "$S/mutate/$m.log" 2>&1
	code=$?
	echo "== $m exit $code ($((SECONDS - t0)) s)"
	grep -E "Tests bestanden|FEHLGESCHLAGEN|bestanden|fehlgeschlagen|FAIL|passed|failed|Skripte|geprüft" "$S/mutate/$m.log" | head -8
	grep -E "^\s+(FAIL|✗|-)|assert|muss|Sprung|Fernboden" "$S/mutate/$m.log" | head -6
done
git checkout -- "$F"
git status --short
