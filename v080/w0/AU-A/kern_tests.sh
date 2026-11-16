#!/usr/bin/env bash
# Runs tools/run_tests.sh of the scratch tree "KERN branch merged with AU-A" with its own XDG_DATA_HOME.
# Usage: kern_tests.sh <log name> [filter]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="${1:-kern_tests}"
shift || true
export XDG_DATA_HOME="$W/xdg_kern_tests"
export TMPDIR="$W/tmp"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME" "$W/logs" "$TMPDIR"
cd "$W/kern_merge" || exit 1
START=$(date +%s)
nice -n 10 tools/run_tests.sh "$@" >"$W/logs/$NAME.log" 2>&1
CODE=$?
END=$(date +%s)
echo "EXIT $CODE  ($((END - START)) s)" >>"$W/logs/$NAME.log"
grep -cE "^ok " "$W/logs/$NAME.log"
grep -E "^FAIL|^==>|Tests,|^CHECK.*FEHLER|EXIT" "$W/logs/$NAME.log" | cut -c1-300
exit $CODE
