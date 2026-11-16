#!/usr/bin/env bash
# AS1R: emit one line per finished phase of after_tests.sh (golden, render check, deliver), then exit.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R
OUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/tasks/bimucg1rk.output
g=0; r=0
while true; do
	if [ $g -eq 0 ] && grep -q '^exit ' "$S/logs/golden.log" 2>/dev/null; then
		echo "GOLDEN: $(grep -E 'GOLDEN|identisch|FEHLER' "$S/logs/golden.log" | tail -3 | tr '\n' ' ') $(tail -1 "$S/logs/golden.log")"
		g=1
	fi
	if [ $r -eq 0 ] && grep -q '^exit ' "$S/logs/render_check.log" 2>/dev/null; then
		echo "RENDER: $(grep -E 'RENDER-CHECK|FEHLER|Fehler' "$S/logs/render_check.log" | tail -4 | tr '\n' ' ') $(tail -1 "$S/logs/render_check.log")"
		r=1
	fi
	if grep -q 'alles fertig' "$OUT" 2>/dev/null; then
		echo "DELIVER: $(tail -6 "$S/logs/deliver.log" | tr '\n' ' ')"
		exit 0
	fi
	if ! pgrep -f after_tests.sh > /dev/null; then
		echo "KETTE BEENDET ohne 'alles fertig': $(tail -3 "$OUT" | tr '\n' ' ')"
		exit 1
	fi
	sleep 15
done
