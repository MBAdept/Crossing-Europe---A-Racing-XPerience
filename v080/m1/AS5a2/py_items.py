"""AS5a2: item specs model@x for the review scenes: x = road edge (centre 7 m, outskirts 13 m) + extent left.
   python3 py_items.py <worktree> <id,id,...> [sep]"""
import json, os, sys
wt, ids = sys.argv[1], sys.argv[2].split(",")
sep = sys.argv[3] if len(sys.argv) > 3 else ";"
out = []
for i in ids:
    mid = i if "/" in i else "props/" + i
    p = os.path.join(wt, "assets/models", mid, "model.json")
    m = json.load(open(p))["model"]
    edge = 13.0 if "outskirts" in m.get("tags", []) else 7.0
    out.append("%s@%.1f" % (mid, edge + float(m["extent_m"]["left"])))
print(sep.join(out))
