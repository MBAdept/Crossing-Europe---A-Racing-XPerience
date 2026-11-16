#!/usr/bin/env bash
# R3E: the final gates on the final head, one after the other.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3E
cd "$WT"
export XDG_DATA_HOME=$S/xdg_final2
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME"
echo "== HEAD $(git rev-parse --short HEAD), $(git status --short | wc -l) geänderte Dateien"
echo "== run_tests.sh $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
nice -n 10 tools/run_tests.sh > "$S/final2_run_tests.log" 2>&1
echo "run_tests EXIT=$?"
echo "== golden.sh check $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
nice -n 10 tools/golden.sh check > "$S/final2_golden.log" 2>&1
echo "golden EXIT=$?"
echo "== run_render_checks.sh modern $(date +%T) load $(cut -d' ' -f1-3 /proc/loadavg)"
nice -n 10 tools/run_render_checks.sh modern > "$S/final2_render.log" 2>&1
echo "render EXIT=$?"
echo "FERTIG $(date +%T)"
