"""AS2a: lamp areas per model and level from an inspect_models.gd report (the validator's own lamp_view).
usage: python3 lamptable.py <inspect.json> [model ids...]"""
import json
import os
import sys

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1"
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
import validate_models as V  # noqa: E402

rep = json.load(open(sys.argv[1]))
man = json.load(open(os.path.join(WT, "assets", "models", "manifest.json")))
ids = sys.argv[2:] or sorted(m for m in man["models"] if m.startswith(("player/", "traffic/")))
meshes = rep["meshes"]
for mid in ids:
    model = man["models"][mid]
    for lod in model["lods"]:
        a = [V.lamp_view(meshes, lod, ch, end, d) for (_l, ch, end, d) in V.LAMP_VIEWS]
        print("%-22s %-6s tail %6.0f  brake %6.0f  ind_r l/r %4.0f / %4.0f  head %5.0f  ind_f l/r %4.0f / %4.0f" % (
            mid, lod["name"], *a))
    anchors = rep.get("anchors", {}).get(mid, [])
    if anchors:
        far = max(anchors, key=lambda e: e.get("dist_mm", 0.0))
        low = max(anchors, key=lambda e: e.get("below_mm", 0.0))
        print("%-22s anchors %d: farthest %.1f mm (%s), deepest below its lamp %.1f mm (%s)" % (
            mid, len(anchors), far.get("dist_mm", 0.0), far.get("role"), low.get("below_mm", 0.0), low.get("role")))
