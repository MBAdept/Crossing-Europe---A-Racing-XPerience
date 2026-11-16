#!/usr/bin/env bash
# AS2R gate 3 (after the last changes to police3d / truck3d / heavy3d): forced export + bake of the police and the
# trucks / buses, git status (empty = identical to the commit), a second bake byte-identical, --check-keys, validator.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
L=$S/logs
cd "$WT"
export XDG_DATA_HOME=$S/xdg
echo "== 3 determinism police + heavy ($(date +%T))"
for g in "police/*" "traffic/truck*" "traffic/bus"; do
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$g" --jobs=1 --force > "$L/gate3_export.log" 2>&1
	echo "export $g exit $?"
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" > "$L/gate3_bake.log" 2>&1
	echo "bake 1 $g exit $?"
done
python3 tools/blender/export_models.py --manifest-only | tail -1
echo "git status after forced export + bake (empty = identical to the commit):"
git status --short | grep -v "^?? tools/kritik/" || true
FILES="assets/models/police assets/models/traffic/truck assets/models/traffic/truck_tarp assets/models/traffic/truck_transport assets/models/traffic/bus"
find $FILES -type f | sort | xargs sha1sum > "$L/det3_hash1.txt"
for g in "police/*" "traffic/truck*" "traffic/bus"; do
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" > "$L/gate3_bake2.log" 2>&1
	echo "bake 2 $g exit $?"
done
find $FILES -type f | sort | xargs sha1sum > "$L/det3_hash2.txt"
echo "files hashed: $(wc -l < "$L/det3_hash1.txt")"
if diff -q "$L/det3_hash1.txt" "$L/det3_hash2.txt" > /dev/null; then echo "second bake byte-identical"; else echo "SECOND BAKE DIFFERS"; fi
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys 2>&1 | tail -2
nice -n 19 python3 tools/blender/validate_models.py --report > "$L/validate_final.log" 2>&1
echo "validate exit $?"
grep -E "CHECK|MB|Modelle" "$L/validate_final.log" | tail -6
echo "gates3.sh fertig ($(date +%T))"
