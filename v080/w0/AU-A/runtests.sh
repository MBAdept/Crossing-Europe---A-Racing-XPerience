#!/usr/bin/env bash
# Runs tools/run_tests.sh of the AU-A worktree with a scratch XDG_DATA_HOME. Usage: runtests.sh <log name> [filter]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="${1:-tests}"
shift || true
export XDG_DATA_HOME="$W/xdg_tests"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME" "$W/logs"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3 || exit 1
START=$(date +%s)
nice -n 10 tools/run_tests.sh "$@" >"$W/logs/$NAME.log" 2>&1
CODE=$?
END=$(date +%s)
echo "EXIT $CODE  ($((END - START)) s)" >>"$W/logs/$NAME.log"
tail -5 "$W/logs/$NAME.log"
exit $CODE
