#!/usr/bin/env bash
# AS5aR1: real exports of the city models (export_models.py, CE_THREADS=3, one worker, nice 19), each baked at once.
#   real.sh <id> [<id> ...]      log lines: EXPORT ..., BAKE ..., === real fertig
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1
source $S/env.sh
export CE_THREADS=3
cd $WT
for id in "$@"; do
	waitmem
	t0=$(date +%s)
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 2>&1 \
		| grep -E "^EXPORT|Error|Traceback|FEHLER|Exception|aus dem Cache" | head -20
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 \
		| grep -E "Modelle|Fehler|FEHLER|ERROR" | tail -2 | sed "s#^#BAKE $id #"
	echo "DONE $id $(( $(date +%s) - t0 )) s $(date +%H:%M)"
done
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "=== real fertig $(date +%H:%M)"
