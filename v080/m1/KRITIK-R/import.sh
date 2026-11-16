#!/bin/bash
# KRITIK-R: import both copies once, one after the other (nice 19).
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
mkdir -p "$K/xdg" "$K/logs"
export XDG_DATA_HOME="$K/xdg"
for d in after before; do
	t0=$(date +%s)
	nice -n 19 godot --headless --path "$K/$d" --import > "$K/logs/import_$d.log" 2>&1
	echo "$d import exit $? in $(( $(date +%s) - t0 )) s"
done
