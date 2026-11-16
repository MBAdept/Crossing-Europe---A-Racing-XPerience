#!/usr/bin/env bash
# AS5a1 scratch: export determinism - a second forced export + bake of some city models must give byte-identical files.
#   det.sh <id>[,<id>...]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
export XDG_DATA_HOME=$S/xdg
export MESA_SHADER_CACHE_DIR=$S/mesa
export CE_THREADS=3
cd "$WT"
IDS="$1"
for id in ${IDS//,/ }; do
	while true; do
		AV=$(free -g | awk '/^Mem:/{print $7}')
		if [ "${AV:-0}" -ge 3 ]; then break; fi
		sleep 60
	done
	before=$(cd tools/blender/_cache3d/$id && sha1sum *.glb 2>/dev/null | sha1sum | cut -c1-12)
	t0=$(date +%s)
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --force --jobs=1 2>&1 \
		| grep -E "^EXPORT|Error|Traceback|FEHLER" | head -5
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 | grep -E "Modelle|FEHLER" | tail -1
	after=$(cd tools/blender/_cache3d/$id && sha1sum *.glb 2>/dev/null | sha1sum | cut -c1-12)
	changed=$(git status --porcelain -- "assets/models/$id" | wc -l)
	echo "DET $id glb vorher $before nachher $after  geänderte Dateien in assets/models/$id: $changed  ($(( $(date +%s) - t0 )) s)"
done
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
git status --porcelain -- assets/models | head -20
echo "=== det fertig $(date +%H:%M)"
