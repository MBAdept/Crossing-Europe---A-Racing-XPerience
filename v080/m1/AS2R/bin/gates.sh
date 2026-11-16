#!/usr/bin/env bash
# AS2R gates, one heavy job after the other (nice 19, one worker):
#   1 determinism: forced export + bake of every vehicle, git status (empty = identical to the commit), a second bake
#     byte-identical, --check-keys
#   2 check_sprite_geometry of the sets whose generators changed (player, showroom; traffic, police, heavy: carbody,
#     vehicles are shared)
# usage: gates.sh [1] [2]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
L=$S/logs
cd "$WT"
export XDG_DATA_HOME=$S/xdg
STEPS=${*:-1 2}
if [[ " $STEPS " == *" 1 "* ]]; then
	echo "== 1 determinism ($(date +%T))"
	for g in "player/*" "traffic/*" "police/*"; do
		nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$g" --jobs=1 --force > "$L/gate_export.log" 2>&1
		echo "export $g exit $?"
		nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" > "$L/gate_bake.log" 2>&1
		echo "bake 1 $g exit $?"
	done
	python3 tools/blender/export_models.py --manifest-only | tail -1
	echo "git status after forced export + bake (empty = identical):"
	git status --short | grep -v "^?? tools/kritik/" || true
	FILES="assets/models/player assets/models/traffic assets/models/police"
	find $FILES -type f | sort | xargs sha1sum > "$L/det_hash1.txt"
	for g in "player/*" "traffic/*" "police/*"; do
		nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$g" > "$L/gate_bake2.log" 2>&1
		echo "bake 2 $g exit $?"
	done
	find $FILES -type f | sort | xargs sha1sum > "$L/det_hash2.txt"
	echo "files hashed: $(wc -l < "$L/det_hash1.txt")"
	if diff -q "$L/det_hash1.txt" "$L/det_hash2.txt" > /dev/null; then echo "second bake byte-identical"; else echo "SECOND BAKE DIFFERS"; fi
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys 2>&1 | tail -2
fi
if [[ " $STEPS " == *" 2 "* ]]; then
	echo "== 2 check_sprite_geometry ($(date +%T))"
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only player,showroom,traffic,police --jobs 1 > "$L/gate_geometry.log" 2>&1
	echo "geometry exit $?"
	tail -4 "$L/gate_geometry.log"
fi
echo "gates.sh fertig ($(date +%T))"
