#!/usr/bin/env bash
# W6: export (Blender, nice 10, one worker) -> bake (Godot) -> import -> manifest.   real.sh <id> [<id> ...]
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
export CE_THREADS=3
cd $WT
for id in "$@"; do
	waitmem
	t0=$(date +%s)
	nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 > $S/logs/real_$(basename $id).log 2>&1
	rc=$?
	echo "EXPORT $id exit $rc $(( $(date +%s) - t0 )) s: $(grep -E '^EXPORT|Traceback|Error' $S/logs/real_$(basename $id).log | grep -v CUEW | tail -2 | tr '\n' ' ')"
	nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 | grep -E "Modelle|FEHLER|ERROR" | tail -2
done
nice -n 10 godot --headless --path . --import > /dev/null 2>&1
nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "=== real fertig $(date +%H:%M)"
