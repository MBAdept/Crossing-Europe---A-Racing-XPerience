#!/usr/bin/env bash
# AS5aR1 scratch (from AS5a1): export determinism - a second forced export + bake of city models must give
# byte-identical files (hashes of the cache intermediates and of the committed folder before and after).
#   det.sh <id>[,<id>...]
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
source $S/env.sh
export CE_THREADS=3
cd "$WT"
IDS="$1"
for id in ${IDS//,/ }; do
	waitmem
	before=$(cd tools/blender/_cache3d/$id && sha1sum *.glb 2>/dev/null | sha1sum | cut -c1-12)
	abefore=$(cd assets/models/$id && sha1sum $(ls | grep -v '\.import$') | sha1sum | cut -c1-12)
	t0=$(date +%s)
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$id" --force --jobs=1 2>&1 \
		| grep -E "^EXPORT|Error|Traceback|FEHLER" | head -5
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$id" 2>&1 | grep -E "Modelle|FEHLER" | tail -1
	after=$(cd tools/blender/_cache3d/$id && sha1sum *.glb 2>/dev/null | sha1sum | cut -c1-12)
	aafter=$(cd assets/models/$id && sha1sum $(ls | grep -v '\.import$') | sha1sum | cut -c1-12)
	echo "DET $id glb $before -> $after  Ordner $abefore -> $aafter  $([ "$abefore" = "$aafter" ] && echo BYTEGLEICH || echo ANDERS)  ($(( $(date +%s) - t0 )) s)"
done
nice -n 19 godot --headless --path . --import > /dev/null 2>&1
echo "=== det fertig $(date +%H:%M)"
