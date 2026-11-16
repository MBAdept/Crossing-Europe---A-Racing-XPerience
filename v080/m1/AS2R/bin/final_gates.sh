#!/usr/bin/env bash
# AS2R final gates, one after the other (nice 19): gate 3 (determinism police + heavy, check-keys, validator),
# tools/run_tests.sh (once), tools/golden.sh check (once).  -> logs/final_gates.log (FINALDONE)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
L=$S/logs
mkdir -p "$S/tmp" "$S/xdg_tests"
"$S/bin/gates3.sh"
cd "$WT"
echo "== run_tests ($(date +%T))"
T0=$(date +%s)
XDG_DATA_HOME=$S/xdg_tests TMPDIR=$S/tmp nice -n 19 tools/run_tests.sh > "$L/run_tests.log" 2>&1
echo "run_tests exit $? in $(( $(date +%s) - T0 )) s"
tail -n 25 "$L/run_tests.log"
echo "== golden check ($(date +%T))"
T0=$(date +%s)
TMPDIR=$S/tmp nice -n 19 tools/golden.sh check > "$L/golden.log" 2>&1
echo "golden exit $? in $(( $(date +%s) - T0 )) s"
tail -n 8 "$L/golden.log"
echo "== FINALDONE ($(date +%T))"
