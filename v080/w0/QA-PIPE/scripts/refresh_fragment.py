"""QA helper: make model.json of a model consistent with its files again (bytes, hash, optional tris) and
regenerate the manifest - so that an attack reaches the check it is aimed at and not the hash check."""
import json, os, sys
T = sys.argv[1]
sys.path.insert(0, os.path.join(T, "tools", "blender"))
from ce3d import manifest as M
mid = sys.argv[2]
folder = os.path.join(M.MODELS_DIR, mid)
frag = M.read_json(os.path.join(folder, "model.json"))
for kv in sys.argv[3:]:
    k, v = kv.split("=", 1)
    path = k.split(".")
    d = frag["model"]
    for p in path[:-1]:
        d = d[int(p)] if p.isdigit() else d[p]
    last = path[-1]
    val = json.loads(v)
    if last.isdigit():
        d[int(last)] = val
    else:
        d[last] = val
digest, total = M.files_hash(folder)
frag["model"]["hash"] = digest
frag["model"]["bytes"] = total
M.write_json(os.path.join(folder, "model.json"), frag)
M.write_manifest()
print("refreshed", mid, total, digest[:12])
