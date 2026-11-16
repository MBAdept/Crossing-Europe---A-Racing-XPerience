#!/usr/bin/env bash
# R6 gates, part A (final head): import, script check, the whole tools/run_tests.sh. Logs in R6/gates/.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
G=$S/gates
mkdir -p "$G" "$S/xdg/gates"
NICE=19
if [ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
	NICE=10
fi
export XDG_DATA_HOME=$S/xdg/gates
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT" || exit 1
echo "HEAD $(git rev-parse --short HEAD)  status: $(git status --short | wc -l) Zeilen  nice $NICE  $(date +%H:%M)"
T0=$SECONDS
nice -n "$NICE" godot --headless --path . --import > "$G/import.log" 2>&1
echo "== import exit $? ($((SECONDS - T0)) s), Fehlerzeilen: $(grep -cE 'ERROR|SCRIPT ERROR|Parse Error' "$G/import.log")"
T0=$SECONDS
nice -n "$NICE" timeout 600 godot --headless --path . -s res://tests/check_scripts.gd > "$G/check_scripts.log" 2>&1
echo "== check_scripts exit $? ($((SECONDS - T0)) s)"
grep -E "geprüft|KAPUTT|SCRIPT ERROR|Parse Error" "$G/check_scripts.log" | head -5
T0=$SECONDS
nice -n "$NICE" tools/run_tests.sh > "$G/run_tests.log" 2>&1
echo "== run_tests exit $? ($((SECONDS - T0)) s)"
grep -E "Tests,|fehlgeschlagen|FEHLER|==>|KAPUTT" "$G/run_tests.log" | tail -25
echo "GATES_A DONE $(date +%H:%M)"
