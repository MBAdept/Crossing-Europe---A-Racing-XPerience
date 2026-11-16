#!/usr/bin/env bash
# Runs godot headless in the scratch tree "KERN branch merged with AU-A" (kern_merge) with its own XDG_DATA_HOME.
# Usage: kern.sh <log name> <godot args…>      log: logs/kern_<name>.log
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="$1"
shift
export XDG_DATA_HOME="$W/xdg_kern_$NAME"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME" "$W/logs"
cd "$W/kern_merge" || exit 1
START=$(date +%s)
timeout -s KILL "${KERN_TIMEOUT:-900}" nice -n 10 godot --headless --path . "$@" >"$W/logs/kern_$NAME.log" 2>&1
CODE=$?
END=$(date +%s)
echo "EXIT $CODE  ($((END - START)) s)" >>"$W/logs/kern_$NAME.log"
grep -E "^CHECK|^ERGEBNIS|^RUN |ERROR|SCRIPT|WARNING|Tests,|FAIL|EXIT" "$W/logs/kern_$NAME.log" | cut -c1-${CUT:-420}
exit $CODE
