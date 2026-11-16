#!/usr/bin/env bash
# R6 gates, part C (final head): tools/run_render_checks.sh <what> [filter]. Logs in R6/gates/.
# Usage: gates_c.sh <all|arcade|modern> [filter] [log name]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
G=$S/gates
mkdir -p "$G" "$S/xdg/gates_rc"
NICE=19
if [ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
	NICE=10
fi
export XDG_DATA_HOME=$S/xdg/gates_rc
export MESA_SHADER_CACHE_DIR=$S/mesa
export RENDER_CHECK_TIMEOUT=${RENDER_CHECK_TIMEOUT:-2400}
cd "$WT" || exit 1
WHAT=${1:-all}
FILTER=${2:-}
NAME=${3:-render_checks_$WHAT}
echo "HEAD $(git rev-parse --short HEAD)  status: $(git status --short | wc -l) Zeilen  nice $NICE  timeout $RENDER_CHECK_TIMEOUT  $(date +%H:%M)"
T0=$SECONDS
nice -n "$NICE" tools/run_render_checks.sh "$WHAT" $FILTER > "$G/$NAME.log" 2>&1
echo "== run_render_checks $WHAT $FILTER exit $? ($((SECONDS - T0)) s)"
grep -E "^RENDER-CHECK-DATEI|^==>" "$G/$NAME.log"
echo "GATES_C DONE $(date +%H:%M)"
