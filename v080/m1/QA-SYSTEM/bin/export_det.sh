#!/bin/bash
# Export determinism of the model pipeline (contract §4.6.1, D18): forced export of a sample of models from the
# generators (Blender 5.2), bake into assets/models, then git must show no change; plus --check-keys.
# Sample covers the material paths: player car with decals and show/shadow (kompakt), traffic car LOD0-2 (hatch),
# card tree with leaf atlas and impostor (tree_birch), Cycles-baked atlas (haybale, customs_booth), lamp channel 12
# with light anchors (streetlight).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/exportdet
mkdir -p "$OUT"
cd "$WT" || exit 2
X=$S/xdg_det; mkdir -p "$X"
PY=/home/user/tools/bpyenv/bin/python
t0=$SECONDS
for m in player/kompakt traffic/hatch props/tree_birch props/haybale props/customs_booth props/streetlight; do
	nice -n 10 $PY tools/blender/export_models.py --only="$m" --force --jobs=1 >> "$OUT/export.log" 2>&1
	echo "export $m exit=$? ($((SECONDS - t0)) s)"
done
grep -E "^EXPORT|FEHLER|Error|Traceback" "$OUT/export.log" | head -20
for m in player/kompakt traffic/hatch props/tree_birch props/haybale props/customs_booth props/streetlight; do
	XDG_DATA_HOME=$X nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="$m" >> "$OUT/bake.log" 2>&1
	echo "bake $m exit=$?"
done
grep -E "Dreiecke|Fehler|ERROR" "$OUT/bake.log" | head -20
echo "-- git status assets/models (leer = byte-gleich):"
git status --porcelain -- assets/models | head -20
echo "-- check-keys:"
nice -n 10 $PY tools/blender/export_models.py --check-keys > "$OUT/check_keys.log" 2>&1
echo "check-keys exit=$?"; tail -3 "$OUT/check_keys.log"
echo "total $((SECONDS - t0)) s"
echo ALLDONE
