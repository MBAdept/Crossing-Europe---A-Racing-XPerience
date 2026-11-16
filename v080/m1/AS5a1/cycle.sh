#!/usr/bin/env bash
# AS5a1 scratch: export (probe = fast preview, or real) -> bake -> import -> manifest for model ids.
#   cycle.sh probe|real|full <id>[,<id>...] [extra probe args]
#   probe: half atlas, 1 sample/supersample (key "debug");  full: real settings (key "debug");  real: export_models.py
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
export CE_THREADS=${CE_THREADS:-2}
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
cd "$WT"
MODE="$1"; shift
IDS="$1"; shift
while true; do
	AV=$(free -g | awk '/^Mem:/{print $7}')
	if [ "${AV:-0}" -ge 3 ]; then break; fi
	echo "wenig Speicher frei ($AV GB) - warte 60 s"; sleep 60
done
t0=$(date +%s)
if [ "$MODE" = "real" ]; then
	for id in ${IDS//,/ }; do
		nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 "$@" 2>&1 \
			| grep -E "^EXPORT|Error|Traceback|FEHLER|Exception|line [0-9]+" | head -20
	done
else
	EXTRA=""
	[ "$MODE" = "full" ] && EXTRA="--full"
	nice -n 19 /home/user/tools/bpyenv/bin/python "$S/probe.py" "$WT" "$IDS" $EXTRA "$@" 2>&1 \
		| grep -E "DEBUG-EXPORT|stats|bake:|lights|lod0|lod1|Error|Traceback|line [0-9]+|Exception" | head -40
fi
echo "export: $(( $(date +%s) - t0 )) s"
for id in ${IDS//,/ }; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 | grep -E "Modelle|Fehler|FEHLER|ERROR" | tail -3
done
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "=== fertig $(date +%H:%M) ($(( $(date +%s) - t0 )) s)"
