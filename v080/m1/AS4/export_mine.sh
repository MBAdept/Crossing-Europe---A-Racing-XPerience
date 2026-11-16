#!/usr/bin/env bash
# AS4 scratch: real export (cache keys) of the AS4 models, one after the other, then bake + import + manifest.
#   export_mine.sh [--force] [ids...]      (default: all AS4 models)
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
export CE_THREADS=2
cd "$WT"
FORCE=""
if [ "${1:-}" = "--force" ]; then FORCE="--force"; shift; fi
IDS=("$@")
if [ ${#IDS[@]} -eq 0 ]; then
	IDS=(props/house_med props/church props/building_shop props/factory props/building_oldtown props/windmill
		props/houseboat props/ferry_ship props/bridge_lamp props/bridge_pylon props/bridge_truss_arch
		props/building_block_a props/building_block_b props/building_tall)
fi
t0=$(date +%s)
for id in "${IDS[@]}"; do
	t1=$(date +%s)
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --jobs=1 $FORCE 2>&1 \
		| grep -E "^EXPORT|Error|Traceback|FEHLER|Exception" | head -8
	echo "    $id: $(( $(date +%s) - t1 )) s"
done
echo "Export gesamt: $(( $(date +%s) - t0 )) s"
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="props/*" 2>&1 | grep -E "Modelle|Fehler|FEHLER|ERROR" | tail -3
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
nice -n 19 python3 tools/blender/export_models.py --manifest-only 2>&1 | tail -1
echo "=== fertig"
