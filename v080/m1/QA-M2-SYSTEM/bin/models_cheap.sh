#!/bin/bash
# Models pipeline, the cheap part: manifest regenerated from the fragments (in the scratch copy) = committed one,
# manifest consistent with every model folder, the validator, --check-keys (Blender, short).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
M=$S/mut
OUT=$S/models
mkdir -p "$OUT"
cd "$M" || exit 2
md5sum assets/models/manifest.json assets/models/sets_default.json > "$OUT/manifest_before.md5"
echo "== manifest-only (python3) =="
python3 tools/blender/export_models.py --manifest-only > "$OUT/manifest_only.log" 2>&1
echo "exit=$?"
tail -3 "$OUT/manifest_only.log"
md5sum -c "$OUT/manifest_before.md5"
cmp assets/models/manifest.json "$WT/assets/models/manifest.json" && echo "manifest regenerated == committed (byte-identical)"
echo "== manifest models vs model folders =="
python3 - "$M/assets/models" <<'EOF'
import json, os, sys, glob
root = sys.argv[1]
m = json.load(open(os.path.join(root, "manifest.json")))
models = m["models"]
folders = set()
for mj in glob.glob(os.path.join(root, "*", "*", "model.json")):
    rel = os.path.relpath(os.path.dirname(mj), root)
    folders.add(rel)
mm = set(models.keys())
print("models in manifest:", len(mm), " model folders with model.json:", len(folders))
print("in manifest, no folder:", sorted(mm - folders))
print("folder, not in manifest:", sorted(folders - mm))
# every mesh/texture path of the manifest exists
missing = []
nfiles = 0
for mid, md in models.items():
    for lod in md.get("lods", []):
        for p in lod.get("parts", []):
            nfiles += 1
            if not os.path.exists(os.path.join(root, p["mesh"])):
                missing.append(p["mesh"])
    if "shadow" in md and isinstance(md["shadow"], dict) and "mesh" in md["shadow"]:
        nfiles += 1
        if not os.path.exists(os.path.join(root, md["shadow"]["mesh"])):
            missing.append(md["shadow"]["mesh"])
    for k, t in (md.get("textures") or {}).items():
        if isinstance(t, str):
            nfiles += 1
            if not os.path.exists(os.path.join(root, t)):
                missing.append(t)
            if not os.path.exists(os.path.join(root, t) + ".import"):
                missing.append(t + ".import")
    imp = md.get("impostor")
    if isinstance(imp, dict) and "texture" in imp:
        nfiles += 1
        if not os.path.exists(os.path.join(root, imp["texture"])):
            missing.append(imp["texture"])
print("referenced files:", nfiles, " missing:", missing[:20], len(missing))
# files in model folders not referenced by the manifest (orphans)
ref = set()
for mid, md in models.items():
    s = json.dumps(md)
    for tok in s.split('"'):
        if "/" in tok and (tok.endswith(".res") or tok.endswith(".png") or tok.endswith(".webp")):
            ref.add(tok)
orph = []
for f in glob.glob(os.path.join(root, "*", "*", "*")):
    rel = os.path.relpath(f, root)
    if rel.endswith((".res", ".png", ".webp")) and rel not in ref:
        orph.append(rel)
print("files in model folders not named by the manifest:", len(orph), orph[:30])
sets = m["sets"]
print("sets:", len(sets), " with model:", sum(1 for s in sets.values() if "model" in s), " fallback:", sum(1 for s in sets.values() if "fallback" in s))
bad = [k for k, s in sets.items() if "model" in s and s["model"] not in models]
print("sets naming a missing model:", bad)
var_bad = [(k, v) for k, s in sets.items() for v in s.get("variants", []) if v not in models]
print("variants naming a missing model:", var_bad)
EOF
echo "== validator =="
( time python3 tools/blender/validate_models.py --report ) > "$OUT/validate.log" 2>&1
echo "exit=$?"
tail -25 "$OUT/validate.log"
cd "$M" && git status --porcelain 2>/dev/null | head -3
echo ALLDONE
