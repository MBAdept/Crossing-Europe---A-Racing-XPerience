#!/usr/bin/env bash
# Repeats runcheck.sh until one run fails or hangs. Usage: loopcheck.sh <count> [extra user args…]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
N="${1:-10}"
shift || true
OK=0
for i in $(seq 1 "$N"); do
	if CUT=10 CHECK_TIMEOUT="${CHECK_TIMEOUT:-60}" "$W/runcheck.sh" "loop_$i" "$@" >/dev/null 2>&1; then
		OK=$((OK + 1))
	else
		echo "Lauf $i fehlgeschlagen oder hängt – Ende des Protokolls:"
		grep -v "^ModernAudio: Profil\|Motorbank" "$W/logs/loop_$i.log" | tail -12 | cut -c1-600
		echo "bestanden bis dahin: $OK"
		exit 1
	fi
done
echo "alle $N Läufe bestanden"
