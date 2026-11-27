#!/usr/bin/env python3
"""N6: add "view_yaw_deg" to the model.json of every landmark model as the exporter now writes it
(props3d._finish_model: model.extra after "roughness", before "auto_lod"), from the LANDMARKS table of
props_landmarks.py. Run from the worktree; then export_models.py --manifest-only. Idempotent."""
import json, os, re
src = open("tools/blender/cesprites/props_landmarks.py").read()
table = src[src.index("\nLANDMARKS = {"):]
table = table[:table.index("\n}")]
yaw = {m.group(1): float(m.group(2)) for m in re.finditer(r'^\s*"([a-z_]+)":\s*\(\w+,\s*\d+,\s*(-?\d+(?:\.\d+)?)', table, re.M)}
done = 0
for name in sorted(os.listdir("assets/models/landmarks")):
    p = os.path.join("assets/models/landmarks", name, "model.json")
    if not os.path.isfile(p) or name not in yaw:
        print("skip", name); continue
    lines = open(p).read().split("\n")
    if any('"view_yaw_deg"' in l for l in lines):
        continue
    i = next(k for k, l in enumerate(lines) if l.startswith('  "auto_lod"'))
    v = yaw[name]
    lines.insert(i, "  \"view_yaw_deg\": %s," % (str(int(v)) if v == int(v) else json.dumps(v)))  # as the bake writes it
    open(p, "w").write("\n".join(lines))
    done += 1
print("patched", done, "of", len(yaw))
