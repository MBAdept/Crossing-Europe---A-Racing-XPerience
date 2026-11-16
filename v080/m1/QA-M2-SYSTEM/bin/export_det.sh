#!/bin/bash
# Models pipeline (contract §4.6.1, D18, A-4): in the SCRATCH COPY $S/mut – forced export of a sample of models from
# the generators (Blender 5.2), bake into assets/models, then the files must equal the committed ones byte for byte;
# a second bake of the same intermediates must be byte-identical too; --check-keys; the sprite geometry against
# the v0.7.0 fixture (check_sprite_geometry.py). Sample over the M2 material paths: truck with retro channel 15
# (AS2R/M2INT), police (police3d), seed variant sharing its species' atlas (olive_b, variant_of), cable-stayed pylon
# (AS4R), church (house builder, baked atlas with night windows).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
M=$S/mut
OUT=$S/exportdet
mkdir -p "$OUT"
cd "$M" || exit 2
X=$S/xdg_det; mkdir -p "$X"
PY=/home/user/tools/bpyenv/bin/python
MODELS=${MODELS:-"traffic/truck police/de props/tree_olive_b props/bridge_pylon props/church"}
t0=$SECONDS
for m in $MODELS; do
	nice -n 10 $PY tools/blender/export_models.py --only="$m" --force --jobs=1 >> "$OUT/export.log" 2>&1
	echo "export $m exit=$? ($((SECONDS - t0)) s)"
done
grep -E "^EXPORT|FEHLER|Error|Traceback" "$OUT/export.log" | head -20
bake() { # tag
	for m in $MODELS; do
		XDG_DATA_HOME=$X nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$m" >> "$OUT/bake_$1.log" 2>&1
		echo "bake[$1] $m exit=$?"
	done
}
bake 1
echo "-- bake 1 vs committed (worktree):"
for m in $MODELS; do
	if diff -rq "$M/assets/models/$m" "$WT/assets/models/$m" > /dev/null; then echo "  $m byte-gleich"; else echo "  $m ANDERS:"; diff -rq "$M/assets/models/$m" "$WT/assets/models/$m" | head -5; fi
done
mkdir -p "$OUT/bake1"
for m in $MODELS; do mkdir -p "$OUT/bake1/$m"; cp -a "$M/assets/models/$m/." "$OUT/bake1/$m/"; done
bake 2
echo "-- bake 2 vs bake 1:"
for m in $MODELS; do
	if diff -rq "$M/assets/models/$m" "$OUT/bake1/$m" > /dev/null; then echo "  $m byte-gleich"; else echo "  $m ANDERS"; diff -rq "$M/assets/models/$m" "$OUT/bake1/$m" | head -5; fi
done
echo "-- check-keys:"
nice -n 10 $PY tools/blender/export_models.py --check-keys > "$OUT/check_keys.log" 2>&1
echo "check-keys exit=$?"; tail -3 "$OUT/check_keys.log"
echo "-- sprite geometry (fixture v0.7.0):"
t1=$SECONDS
nice -n 10 $PY tools/blender/check_sprite_geometry.py --jobs 2 > "$OUT/sprite_geometry.log" 2>&1
echo "check_sprite_geometry exit=$? $((SECONDS - t1)) s"; tail -5 "$OUT/sprite_geometry.log"
echo "total $((SECONDS - t0)) s"
echo ALLDONE
