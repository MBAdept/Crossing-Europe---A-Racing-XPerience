#!/usr/bin/env bash
# AS1b scratch: several cycle.sh runs one after the other (one heavy job at a time)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1b
for g in "$@"; do
	echo "=== $g"
	$S/cycle.sh "$g" 2>&1 | grep -E "EXPORT|Error|Trace|line [0-9]|props/|FEHLER"
done
echo "=== fertig"
