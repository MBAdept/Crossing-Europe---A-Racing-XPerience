#!/usr/bin/env bash
# M2INT: tools/run_tests.sh [filter] with an absolute XDG_DATA_HOME, niceness by the lead's ZS1_FERTIG; log per filter
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
NICE=19
[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
export XDG_DATA_HOME=$S/xdg_tests
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME" "$S/logs"
cd "$WT"
TAG=${1:-ALL}
t0=$(date +%s)
nice -n $NICE tools/run_tests.sh "$@" > "$S/logs/tests_$TAG.log" 2>&1
code=$?
echo "run_tests $TAG exit $code ($(( $(date +%s) - t0 )) s, nice $NICE)"
grep -E "Tests (bestanden|FEHLGESCHLAGEN)|fehlgeschlagen|FEHLER|FAIL|SCRIPT ERROR|Parse Error|geprüft|bestanden|Ergebnis|passed|failed" "$S/logs/tests_$TAG.log" | tail -40
exit $code
