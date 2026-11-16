#!/usr/bin/env bash
# FIX-WASSER-R: after the gates – only if every gate passed: build, deliver (old files to alt/), smokes.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
G=$S/gates
until grep -q 'render_checks exit' "$G/summary.txt"; do sleep 10; done
ok=1
grep -q 'run_tests exit 0' "$G/summary.txt" || ok=0
grep -q 'golden_check exit 0' "$G/summary.txt" || ok=0
grep -q 'golden_modern_check exit 0' "$G/summary.txt" || ok=0
grep -q 'render_checks exit 0' "$G/summary.txt" || ok=0
grep -q 'GOLDEN arcade: 20 von 20 identisch' "$G/summary.txt" || ok=0
if [ $ok -ne 1 ]; then
	echo "== Gates nicht alle grün – kein Build $(date -u +%T)"
	exit 1
fi
echo "== Gates grün, Build $(date -u +%T)"
bash "$S/build.sh" > "$S/logs/build.log" 2>&1
code=$?
echo "build exit $code $(date -u +%T)"
[ $code -eq 0 ] || exit $code
bash "$S/deliver.sh" > "$S/logs/deliver.log" 2>&1
echo "deliver exit $? $(date -u +%T)"
bash "$S/smokes.sh" > "$S/logs/smokes.log" 2>&1
echo "smokes exit $? $(date -u +%T)"
