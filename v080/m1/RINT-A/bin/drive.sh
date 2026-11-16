#!/bin/bash
# Kiel – Hamburg from start to finish in Modern under Xvfb (real renderer), autopilot, preset medium:
#   drive.sh <name> [extra args]   -> $S/logs/drive_<name>.log ; prints ERGEBNIS / PERF / RUN and the log's warnings
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
name=$1; shift
log="$S/logs/drive_$name.log"
start=$(date +%s)
nice -n 10 timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 -s res://tests/race/run_stage.gd -- --stage=kiel_hamburg --from=kiel --graphics=modern \
	--gfx-preset=medium --vehicle=limousine --hour=12 --timescale=4 --max-seconds=2900 "$@" > "$log" 2>&1
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s  (log $log)"
grep -E "^ERGEBNIS|^RUN |FEHLER" "$log" | cut -c1-400
echo "--- warnings/errors (count, unique):"
grep -E "^(WARNING|ERROR|SCRIPT ERROR)|SHADER ERROR|leaked|still in use" "$log" | sort | uniq -c | sort -rn | head -20
