#!/usr/bin/env bash
# AS2a: export determinism - forced re-export of every vehicle, bake, git status must stay clean; a second bake must
# give the same files; then the cache-key self test. Run on a committed tree.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a
export XDG_DATA_HOME=$S/xdg
cd "$WT"
echo "== status vorher"; git status --short | head
for g in "player/*" "traffic/*"; do
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$g" --jobs=1 --force > "$S/logs/det_export.log" 2>&1
	echo "export $g exit $?"; grep -E "EXPORT" "$S/logs/det_export.log" | head -12
done
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="player/*" > "$S/logs/det_bake1.log" 2>&1
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="traffic/*" >> "$S/logs/det_bake1.log" 2>&1
python3 tools/blender/export_models.py --manifest-only > /dev/null 2>&1
echo "== status nach erzwungenem Export + Bake (leer = byte-gleich)"; git status --short | head -20
md5sum $(find assets/models/player assets/models/traffic -type f | sort) > "$S/logs/det_md5_1.txt"
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="player/*" > "$S/logs/det_bake2.log" 2>&1
nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="traffic/*" >> "$S/logs/det_bake2.log" 2>&1
md5sum $(find assets/models/player assets/models/traffic -type f | sort) > "$S/logs/det_md5_2.txt"
if cmp -s "$S/logs/det_md5_1.txt" "$S/logs/det_md5_2.txt"; then echo "zweiter Bake: byte-gleich ($(wc -l < $S/logs/det_md5_1.txt) Dateien)"; else echo "zweiter Bake: ABWEICHUNG"; diff "$S/logs/det_md5_1.txt" "$S/logs/det_md5_2.txt" | head; fi
nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys 2>&1 | grep -E "CHECK|FEHLER|problem" | tail -5
echo "== status am Ende"; git status --short | head
