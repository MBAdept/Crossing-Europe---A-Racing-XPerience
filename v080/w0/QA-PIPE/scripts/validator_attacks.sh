#!/usr/bin/env bash
# QA: attacks on tools/blender/validate_models.py. Works on the scratch tree and restores it after each attack.
set -u
Q=$1; W=$2; T=$Q/tree
export XDG_DATA_HOME=$Q/xdg
restore() { rm -rf $T/assets/models; cp -a $W/assets/models $T/assets/models; }
run() { (cd $T && python3 tools/blender/validate_models.py 2>&1 | grep -E "FEHLER|CHECK" | cut -c1-230 | head -${1:-8}); }
cd $T
echo "== V0 baseline"; restore; run
echo "== V1 a model really over budget: the sedan's lod0 body replaced by the limousine's show body (85,962 triangles), fragment and manifest made consistent"
cp assets/models/player/limousine/show_body.res assets/models/traffic/sedan/lod0_body.res
python3 $Q/scripts/refresh_fragment.py $T traffic/sedan lods.0.tris=87994 >/dev/null; run
echo "== V1b the same, but the manifest keeps saying 17276 triangles"
restore; cp assets/models/player/limousine/show_body.res assets/models/traffic/sedan/lod0_body.res
python3 $Q/scripts/refresh_fragment.py $T traffic/sedan >/dev/null; run
echo "== V1c lod2 one triangle budget lower than it is: 1144 triangles against a budget of 1200 (headroom 56) - shadow caster over budget instead"
restore; cp assets/models/traffic/sedan/lod1_body.res assets/models/traffic/sedan/shadow.res
python3 $Q/scripts/refresh_fragment.py $T traffic/sedan shadow.tris=4147 >/dev/null; run
echo "== V2 a sprite set without a sets entry (props/barn removed from sets_default.json and the manifest)"
restore; python3 - <<PY
import json
for f in ("assets/models/sets_default.json", "assets/models/manifest.json"):
    d = json.load(open(f)); d["sets"].pop("props/barn"); json.dump(d, open(f, "w"))
PY
run
echo "== V2b the same, written with the pipeline's own writer (only the defaults file edited, manifest regenerated)"
restore; python3 - <<PY
import sys; sys.path.insert(0, "tools/blender")
from ce3d import manifest as M
import os
p = os.path.join(M.MODELS_DIR, M.DEFAULT_SETS); d = M.read_json(p); d["sets"].pop("props/barn"); M.write_json(p, d); M.write_manifest()
PY
run
echo "== V2c a vehicle set turned into a sprite stand-in (traffic/hatch_red: box -> sprite)"
restore; python3 - <<PY
import sys; sys.path.insert(0, "tools/blender")
from ce3d import manifest as M
import os
p = os.path.join(M.MODELS_DIR, M.DEFAULT_SETS); d = M.read_json(p); d["sets"]["traffic/hatch_red"]["fallback"] = "sprite"; M.write_json(p, d); M.write_manifest()
PY
run
echo "== V3 object size 3 % off the sprite manifest (sedan width 1.82 -> 1.875)"
restore; python3 $Q/scripts/refresh_fragment.py $T traffic/sedan object.width_m=1.875 >/dev/null; run
echo "== V3b object size 1.9 % off (inside the tolerance: 1.82 -> 1.854) - the validator accepts, the unit test must not"
restore; python3 $Q/scripts/refresh_fragment.py $T traffic/sedan object.width_m=1.854 >/dev/null; run
(cd $T && tools/run_tests.sh test_model_db 2>&1 | grep -E "FAIL|fehlgeschlagen|object" | head -5)
echo "== V4 a texture without its .import"
restore; rm assets/models/props/farmhouse/albedo.png.import; run
echo "== V5 texture over the tier: farmhouse albedo 2048 px (rural tier 1024)"
restore; python3 - <<PY
from PIL import Image
p = "assets/models/props/farmhouse/albedo.png"
Image.open(p).resize((2048, 2048)).save(p)
PY
python3 $Q/scripts/refresh_fragment.py $T props/farmhouse >/dev/null; godot --headless --path . --import >/dev/null 2>&1; run
echo "== V6 a wheel 2 cm above the ground"
restore; godot --headless --path . --import >/dev/null 2>&1
python3 $Q/scripts/refresh_fragment.py $T traffic/sedan lods.0.parts.1.pos='[-0.7525, 0.34, -1.415]' >/dev/null; run
echo "== V7 a stray file and a .glb in a model folder"
restore; echo x > assets/models/props/streetlight/notiz.txt; cp $T/tools/blender/_cache3d/props/streetlight/model.glb assets/models/props/streetlight/; cp assets/models/props/streetlight/lod0_body.res assets/models/props/streetlight/alt.res; run
echo "== V8 a model folder without model.json and an unknown group"
restore; mkdir -p assets/models/props/halbfertig assets/models/extras/ding; cp assets/models/props/streetlight/lod0_body.res assets/models/props/halbfertig/; run
echo "== V9 set pointing to a level the model does not have / unknown model"
restore; python3 - <<PY
import json
f = "assets/models/props/streetlight/model.json"; d = json.load(open(f)); d["sets"]["props/streetlight"] = {"model": "props/streetlight", "lod": "show"}; json.dump(d, open(f, "w"))
PY
python3 - <<PY
import sys; sys.path.insert(0, "tools/blender")
from ce3d import manifest as M
M.write_manifest()
PY
run
echo "== V10 unknown node name, unknown class, unknown light role, kind"
restore; python3 $Q/scripts/refresh_fragment.py $T traffic/sedan lods.0.parts.1.node='"rad_vl"' lods.1.parts.0.classes='["vpbr", "chrome"]' lights.0.role='"fog"' >/dev/null; run 10
restore; godot --headless --path . --import >/dev/null 2>&1
echo "== restored"; run; (cd $T && find assets/models -type f | sort | xargs md5sum | diff - $Q/committed.md5 && echo "tree back at the committed state")
