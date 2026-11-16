#!/bin/bash
# Runs the jobs of a job file one after the other (one Godot at a time): each line "<name>|<timeout s>|<godot args>".
# Waits first until the log named in $WAIT_LOG has its EXIT line (a job already running). Marks progress in queue.state.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN
JOBS=$1
if [ -n "$WAIT_LOG" ]; then
	until grep -q "^EXIT" "$WAIT_LOG" 2>/dev/null; do sleep 10; done
fi
while IFS='|' read -r name to args; do
	[ -z "$name" ] && continue
	case "$name" in \#*) continue ;; esac
	if grep -q "^DONE $name\$" $S/queue.state 2>/dev/null; then continue; fi
	echo "START $name $(date +%T)" >> $S/queue.state
	# shellcheck disable=SC2086
	eval bash $S/run_godot.sh "$S/runs/$name.log" "$to" $args
	echo "DONE $name" >> $S/queue.state
done < "$JOBS"
echo "QUEUE END $(date +%T)" >> $S/queue.state
