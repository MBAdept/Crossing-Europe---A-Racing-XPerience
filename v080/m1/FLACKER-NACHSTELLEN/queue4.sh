#!/bin/bash
# Run 4 queue: one Godot at a time. Lines "<name>|<timeout s>|<outdir>|<godot args>". State in queue4.state.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN
JOBS=$1
ST=${STATE:-$S/queue4.state}
while IFS='|' read -r name to dir args; do
	[ -z "$name" ] && continue
	case "$name" in \#*) continue ;; esac
	if grep -q "^DONE $name " $ST 2>/dev/null; then continue; fi
	echo "START $name $(date +%T)" >> $ST
	eval bash $S/run_godot.sh "$dir/$name.log" "$to" $args
	echo "DONE $name $(date +%T) $(tail -n 1 $dir/$name.log)" >> $ST
done < "$JOBS"
echo "QUEUE END $JOBS $(date +%T)" >> $ST
