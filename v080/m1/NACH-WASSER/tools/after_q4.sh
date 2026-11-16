#!/usr/bin/env bash
# NACH-WASSER: after queue 4 – the unit tests of the props builder on 39849f0 (tools/run_tests.sh test_props), one job.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-4
until grep -q "^== queue4 exit" "$S/logs/after_rest.log" 2>/dev/null; do sleep 5; done
mkdir -p "$S/xdg/tests" "$S/tmp_tests"
t0=$SECONDS
(cd "$W" && XDG_DATA_HOME="$S/xdg/tests" TMPDIR="$S/tmp_tests" nice -n 10 tools/run_tests.sh test_props) > "$S/logs/tests_props.log" 2>&1
echo "== test_props exit $? ($((SECONDS - t0)) s) $(date -u +%T)"
