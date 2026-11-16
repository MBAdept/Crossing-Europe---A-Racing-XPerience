"""AS4R scratch: budget table (markdown) of the AS4 models from the manifest, the model folders and the export report.
   python3 budget_table.py <worktree>"""
import json
import os
import sys

WT = sys.argv[1]
sys.path.insert(0, os.path.join(WT, "tools", "blender"))
from ce3d import manifest as M  # noqa: E402

IDS = ["props/house_med", "props/church", "props/factory", "props/building_shop", "props/building_oldtown",
       "props/building_block_a", "props/building_block_b", "props/building_tall", "props/windmill", "props/houseboat",
       "props/ferry_ship", "props/bridge_lamp", "props/bridge_pylon", "props/bridge_pylon_bare", "props/bridge_truss_arch"]
LIMIT = {"rural": "2 000 / 2", "city": "10 000 / 2", "furniture": "1 500 / 1", "pylon": "5 000 / 1"}
man = json.load(open(os.path.join(WT, "assets/models/manifest.json")))
rep_path = os.path.join(WT, "tools/blender/_cache3d/export_report.json")
rep = json.load(open(rep_path)) if os.path.exists(rep_path) else {}
bake_path = os.path.join(WT, "tools/blender/_cache3d/bake_report.json")
bake = json.load(open(bake_path)) if os.path.exists(bake_path) else {}
print("| Modell | Kategorie (Budget Dr. / Aufrufe) | Dreiecke je Stufe | Aufrufe | Netze B | Texturen (Quelle B) | "
      "Atlas | px/m | Export s | Bake s |")
print("|---|---|---|---|---|---|---|---|---|---|")
tot_mesh = tot_tex = 0
for mid in IDS:
    m = man["models"].get(mid)
    if m is None:
        print("| %s | fehlt |" % mid)
        continue
    cat = M.category(mid, m)
    lods = " · ".join("%s %d" % (l["name"], l["tris"]) for l in m["lods"])
    draws = "/".join(str(sum(len(p["classes"]) for p in l["parts"])) for l in m["lods"])
    folder = os.path.join(WT, "assets/models", mid)
    mesh_b = sum(os.path.getsize(os.path.join(folder, f)) for f in os.listdir(folder) if f.endswith(".res"))
    tex = [f for f in os.listdir(folder) if f.endswith((".png", ".webp"))]
    tex_b = sum(os.path.getsize(os.path.join(folder, f)) for f in tex)
    tot_mesh += mesh_b
    tot_tex += tex_b
    st = rep.get(mid, {})
    bk = st.get("bake", {})
    atlas = "x".join(str(v) for v in bk.get("atlas", [])) or "-"
    ppm = bk.get("ppm", "-")
    print("| `%s` | %s (%s) | %s | %s | %d | %s (%d) | %s | %s | %s | %s |" % (
        mid, cat, LIMIT.get(cat, "?"), lods, draws, mesh_b, ", ".join(sorted(tex)) or "-", tex_b, atlas, ppm,
        st.get("export_s", "-"), bake.get(mid, {}).get("bake_s", "-")))
print()
print("Summe AS4R: Netze %d B (%.2f MB), Texturquellen %d B (%.2f MB)" % (tot_mesh, tot_mesh / 1048576.0, tot_tex,
                                                                         tot_tex / 1048576.0))
