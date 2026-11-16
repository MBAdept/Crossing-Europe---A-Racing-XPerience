#!/usr/bin/env bash
# NACH-WASSER: queue 4 once rest.sh (queue 2, golden, queue 3) has finished – one heavy job at a time.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
until grep -q "^== rest fertig" "$S/logs/rest.log"; do sleep 5; done
"$S/tools/queue4.sh" > "$S/logs/queue4.log" 2>&1
echo "== queue4 exit $? $(date -u +%T)"
