#!/bin/bash
# waitq.sh <regex in queue9.log> [max seconds, default 560] [log to show] – waits, then prints the tail of the log
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
PAT=$1
MAX=${2:-560}
SHOW=${3:-}
T0=$(date +%s)
while ! grep -qE "$PAT" "$R4/queue9.log" 2>/dev/null; do
	[ $(( $(date +%s) - T0 )) -ge "$MAX" ] && break
	sleep 10
done
tail -3 "$R4/queue9.log"
if [ -n "$SHOW" ]; then
	grep -a -E "RENDER-CHECK|CHECK|==>|FEHLER|FAIL|SCRIPT ERROR|SHADER ERROR" "$SHOW" | cut -c1-220 | tail -${TAILN:-12}
fi
echo "load $(cut -d' ' -f1 /proc/loadavg) $(date -u +%T)"
