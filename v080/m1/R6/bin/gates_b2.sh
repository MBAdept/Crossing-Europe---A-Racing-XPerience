#!/usr/bin/env bash
# R6 gates, part B (final head): Arcade identity (golden.sh check), Modern change detectors (modern-check, pictures
# kept), the two Modern simulation checks with --full. Logs in R6/gates/.
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
T0=$SECONDS
nice -n "$NICE" timeout 3600 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > "$G/modern_sight.log" 2>&1
echo "== modern_sight --full exit $? ($((SECONDS - T0)) s)"
grep -E "^CHECK|FEHLER" "$G/modern_sight.log" | tail -12
T0=$SECONDS
nice -n "$NICE" timeout 3600 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > "$G/modern_path_check.log" 2>&1
echo "== modern_path_check --full exit $? ($((SECONDS - T0)) s)"
grep -E "^CHECK|FEHLER" "$G/modern_path_check.log" | tail -8
echo "GATES_B2 DONE $(date +%H:%M)"
