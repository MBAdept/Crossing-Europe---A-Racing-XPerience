#!/usr/bin/env bash
# NACH-WASSER: after queue 1 – queue 2 (Windows/Wine), then tools/golden.sh check (once), then queue 3 (Linux extras).
# Strictly one heavy job at a time. Logs in m1/NACH-WASSER/logs/.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-4
until grep -q "^== fertig" "$S/logs/queue1.log"; do sleep 5; done
echo "== queue2 $(date -u +%T)"
"$S/tools/queue2.sh" > "$S/logs/queue2.log" 2>&1
echo "== queue2 exit $? $(date -u +%T)"
echo "== golden check $(date -u +%T)"
mkdir -p "$S/tmp_golden"
(cd "$W" && TMPDIR="$S/tmp_golden" KEEP="$S/golden_keep" tools/golden.sh check) > "$S/logs/golden.log" 2>&1
echo "== golden exit $? $(date -u +%T)"
echo "== queue3 $(date -u +%T)"
"$S/tools/queue3.sh" > "$S/logs/queue3.log" 2>&1
echo "== queue3 exit $? $(date -u +%T)"
echo "== rest fertig $(date -u +%T)"
