#!/usr/bin/env bash
# AS2b gate: forced re-export + bake of all AS2b models must leave the repository unchanged; a second bake must be
# byte-identical; --check-keys green. One heavy job at a time, nice 19, one worker.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2b
export XDG_DATA_HOME=$S/xdg
L=$S/logs/determinism.log
: > "$L"
cd "$WT"
GLOBS=("police/*" "traffic/bus" "traffic/truck*")
FILES="assets/models/police assets/models/traffic/bus assets/models/traffic/truck assets/models/traffic/truck_tarp assets/models/traffic/truck_transport"
for g in "${GLOBS[@]}"; do
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$g" --jobs=1 --force >> "$L" 2>&1
	echo "export $g exit $?" | tee -a "$L"
done
for g in "${GLOBS[@]}"; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" >> "$L" 2>&1
	echo "bake 1 $g exit $?" | tee -a "$L"
done
python3 tools/blender/export_models.py --manifest-only >> "$L" 2>&1
echo "== git status after forced export + bake (empty = identical):"
git status --short
find $FILES -type f | sort | xargs sha1sum > "$S/logs/det_hash1.txt"
for g in "${GLOBS[@]}"; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" >> "$L" 2>&1
	echo "bake 2 $g exit $?" | tee -a "$L"
done
find $FILES -type f | sort | xargs sha1sum > "$S/logs/det_hash2.txt"
echo "== files hashed: $(wc -l < "$S/logs/det_hash1.txt")"
if diff -q "$S/logs/det_hash1.txt" "$S/logs/det_hash2.txt" > /dev/null; then echo "second bake byte-identical"; else echo "SECOND BAKE DIFFERS"; fi
echo "== git status after second bake:"
git status --short
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys 2>&1 | tail -3
echo "determinism.sh fertig"
