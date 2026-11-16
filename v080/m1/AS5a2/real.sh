#!/usr/bin/env bash
# AS5a2: real exports (export_models.py, CE_THREADS=3, nice 19, one worker) -> bake -> import -> manifest
#   real.sh <id> [<id> ...]
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2/env.sh
export CE_THREADS=3
cd $WT
for id in "$@"; do
	waitmem
	t0=$(date +%s)
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 > $S/logs/real_$(basename $id).log 2>&1
	echo "EXPORT $id exit $? $(( $(date +%s) - t0 )) s: $(grep -E '^EXPORT|Traceback|Error' $S/logs/real_$(basename $id).log | grep -v CUEW | tail -2 | tr '\n' ' ')"
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 | grep -E "Modelle|FEHLER|ERROR" | tail -2
done
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "=== real fertig $(date +%H:%M)"
