#!/usr/bin/env bash
# FIX-ZS1: the gates on the final head, one after the other; logs in m1/FIX-ZS1/gates/
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
G=$S/gates
mkdir -p "$G"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
echo "HEAD $(git rev-parse HEAD) $(date -u +%T)" | tee "$G/summary.txt"
git status --short | tee -a "$G/summary.txt"
export XDG_DATA_HOME=$S/xdg_gates
mkdir -p "$XDG_DATA_HOME"
step() {
	local name=$1
	shift
	local t0=$SECONDS
	echo "== $name start $(date -u +%T)" | tee -a "$G/summary.txt"
	"$@" >"$G/$name.log" 2>&1
	local code=$?
	echo "== $name exit $code ($((SECONDS - t0)) s)" | tee -a "$G/summary.txt"
}
step import nice -n 5 timeout 900 godot --headless --path . --import
grep -cE "ERROR|SCRIPT ERROR" "$G/import.log" | sed 's/^/   import: Fehlerzeilen /' | tee -a "$G/summary.txt"
step check_scripts nice -n 5 timeout 600 godot --headless --path . -s res://tests/check_scripts.gd
grep -E "geprüft|KAPUTT" "$G/check_scripts.log" | tee -a "$G/summary.txt"
step run_tests nice -n 5 timeout 3000 tools/run_tests.sh
tail -25 "$G/run_tests.log" | grep -E "Tests|bestanden|FEHL|fehlgeschlagen|==>" | tee -a "$G/summary.txt"
step golden_check nice -n 5 timeout 2400 tools/golden.sh check
grep -E "GOLDEN" "$G/golden_check.log" | tee -a "$G/summary.txt"
step golden_modern_check nice -n 5 timeout 3000 tools/golden.sh modern-check
grep -E "GOLDEN" "$G/golden_modern_check.log" | tee -a "$G/summary.txt"
step render_checks nice -n 5 timeout 4800 tools/run_render_checks.sh all
grep -E "RENDER-CHECK-DATEI|==>" "$G/render_checks.log" | tee -a "$G/summary.txt"
echo "== fertig $(date -u +%T)" | tee -a "$G/summary.txt"
