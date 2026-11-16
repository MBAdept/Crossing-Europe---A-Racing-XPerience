#!/usr/bin/env bash
# AS5aR1 scratch (from AS5a1): export (probe = fast preview, full = real bake settings, real = export_models.py)
# -> bake -> import -> manifest for model ids.
#   cycle.sh probe|real|full <id>[,<id>...] [extra args]
#   probe: half atlas, 1 sample/supersample (key "debug");  full: real settings (key "debug");  real: export_models.py
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2/env.sh
export CE_THREADS=${CE_THREADS:-3}
cd "$WT"
MODE="$1"; shift
IDS="$1"; shift
waitmem
t0=$(date +%s)
if [ "$MODE" = "real" ]; then
	for id in ${IDS//,/ }; do
		nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 "$@" 2>&1 \
			| grep -E "^EXPORT|Error|Traceback|FEHLER|Exception|line [0-9]+" | head -20
	done
else
	EXTRA=""
	[ "$MODE" = "full" ] && EXTRA="--full"
	nice -n 19 /home/user/tools/bpyenv/bin/python "$S/tools/probe.py" "$WT" "$IDS" $EXTRA "$@" 2>&1 \
		| grep -E "DEBUG-EXPORT|stats|bake:|lights|lod0|lod1|Error|Traceback|line [0-9]+|Exception" | head -60
fi
echo "export: $(( $(date +%s) - t0 )) s"
for id in ${IDS//,/ }; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 | grep -E "Modelle|Fehler|FEHLER|ERROR" | tail -3
done
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "=== fertig $(date +%H:%M) ($(( $(date +%s) - t0 )) s)"
