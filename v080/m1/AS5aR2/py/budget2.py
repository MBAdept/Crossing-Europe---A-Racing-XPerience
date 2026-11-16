"""AS5a1 scratch: budget table of the city models from the export report, model.json and the imported textures.
   python3 budget.py <worktree>"""
import json
import os
import re
import sys
import zlib

WT = sys.argv[1]
IDS = ['props/city_french_sud', 'props/city_belgian_terrace', 'props/city_french_maison', 'props/city_french_immeuble', 'props/city_dutch_terrace', 'props/city_belgian_stone', 'props/city_paris_haussmann', 'props/city_swiss_chalet', 'props/city_dutch_canal', 'props/city_swiss_laube', 'props/city_dutch_canal_b', 'props/city_paris_corner']
rep = json.load(open(os.path.join(WT, "tools/blender/_cache3d/export_report.json")))
MB = 1e6
tot = dict(mesh=0, mesh_z=0, tex=0, tex_z=0)
print("| Modell | Dreiecke lod0 / lod1 | Aufrufe je Stufe | Atlas | px/m Straße min–max | Rückseite | Netze B (Archiv) |"
      " Texturen PCK (Archiv) | Bake s |")
print("|---|---|---|---|---|---|---|---|---|")
for mid in IDS:
    folder = os.path.join(WT, "assets/models", mid)
    mj = os.path.join(folder, "model.json")
    if not os.path.exists(mj):
        print("| %s | fehlt |" % mid)
        continue
    m = json.load(open(mj))["model"]
    tris = " / ".join("%d" % l["tris"] for l in m["lods"])
    calls = "/".join("%d" % len(set(c for p in l["parts"] for c in p["classes"])) for l in m["lods"])
    r = rep.get(mid, {})
    b = r.get("bake", {})
    mesh = mesh_z = tex = tex_z = 0
    for f in sorted(os.listdir(folder)):
        p = os.path.join(folder, f)
        if f.endswith(".res") or f == "model.json":
            data = open(p, "rb").read()
            mesh += len(data)
            mesh_z += len(zlib.compress(data, 9))
        elif f.endswith((".png", ".webp")):
            txt = open(p + ".import").read() if os.path.exists(p + ".import") else ""
            mm = re.search(r'path(?:\.s3tc)?="res://(\.godot/imported/[^"]+)"', txt)
            if mm:
                data = open(os.path.join(WT, mm.group(1)), "rb").read()
                tex += len(data)
                tex_z += len(zlib.compress(data, 9))
    for k, v in (("mesh", mesh), ("mesh_z", mesh_z), ("tex", tex), ("tex_z", tex_z)):
        tot[k] += v
    far = "%s gespiegelt, %s eigene" % (r.get("far_faces", "–"), r.get("far_kept", "–"))
    print("| `%s` | %s | %s | %s | %s–%s | %s | %d (%d) | %d (%d) | %s |" % (
        mid.split("/")[1], tris, calls, "×".join(str(v) for v in b.get("atlas", [])),
        b.get("ppm_road_min", "–"), b.get("ppm_road_max", "–"), far, mesh, mesh_z, tex, tex_z,
        r.get("export_s", "–")))
print()
print("Summe: Netze %.2f MB (Archiv %.2f MB), Texturen %.2f MB im PCK (Archiv %.2f MB)" % (
    tot["mesh"] / MB, tot["mesh_z"] / MB, tot["tex"] / MB, tot["tex_z"] / MB))
