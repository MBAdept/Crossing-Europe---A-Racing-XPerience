#!/usr/bin/env bash
# FIX-WASSER queue 3: waits for queue 2, then the test build from the committed head and everything with the exports
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
until grep -q '^== fertig' "$S/queue2.log"; do sleep 5; done
echo "== build $(date -u +%T)"
bash "$S/build.sh" > "$S/build.log" 2>&1
echo "build exit $? $(date -u +%T)"
grep -E '^exit|OK$|FEHL|==>' "$S/build.log" | tail -12
echo "== smokes $(date -u +%T)"
bash "$S/smokes.sh" > "$S/smokes.log" 2>&1
echo "smokes exit $? $(date -u +%T)"
grep -E "^== |exit|SMOKE|OK|FEHL" "$S/smokes.log" | tail -40
echo "== fertig $(date -u +%T)"
