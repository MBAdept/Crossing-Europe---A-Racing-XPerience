#!/usr/bin/env bash
# AS4R scratch: the last gates on the final head, strictly one heavy job after the other:
#   second forced export of all 15 models (must leave the working tree unchanged = byte-identical),
#   validator report, tools/run_tests.sh (once), tools/golden.sh check (once).
# tools/kritik must be deleted before (separately).
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-6
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4R
L=$S/logs/final_gates.log
mkdir -p "$S/gates" "$S/xdg_tests" "$S/tmp_golden"
: > "$L"
echo "start $(date +%H:%M) head $(git -C "$WT" rev-parse --short HEAD)" >> "$L"
t0=$(date +%s)
"$S/export_mine.sh" --force > "$S/gates/export_force.log" 2>&1
echo "export_force rc $? $(( $(date +%s) - t0 )) s $(date +%H:%M)" >> "$L"
git -C "$WT" status --porcelain > "$S/gates/status_after_force.txt"
echo "status_lines $(wc -l < "$S/gates/status_after_force.txt")" >> "$L"
git -C "$WT" diff --stat > "$S/gates/diff_after_force.txt"
cd "$WT"
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/validate_models.py --report > "$S/gates/validate.log" 2>&1
echo "validate rc $? $(date +%H:%M)" >> "$L"
t0=$(date +%s)
XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh > "$S/gates/run_tests.log" 2>&1
echo "run_tests rc $? $(( $(date +%s) - t0 )) s $(date +%H:%M)" >> "$L"
t0=$(date +%s)
TMPDIR=$S/tmp_golden nice -n 19 tools/golden.sh check > "$S/gates/golden.log" 2>&1
echo "golden rc $? $(( $(date +%s) - t0 )) s $(date +%H:%M)" >> "$L"
echo FINAL_GATES_DONE >> "$L"
