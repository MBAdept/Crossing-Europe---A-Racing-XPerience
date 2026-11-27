#!/usr/bin/env python3
"""W6 scratch: table of the 23 AS5b city models for docs/modelle.md section 23 (export report, model.json,
deflate -9 per file like tools/pck_report.py, placements from the AS5a1 census)."""
import json, os, sys, zlib
WT = sys.argv[1]; W6 = sys.argv[2]
rep = json.load(open(os.path.join(WT, "tools/blender/_cache3d/export_report.json")))
cen = {}
for line in open(os.path.join(W6, "census_as5b.txt")):
    mid, n, sc = line.split(); cen[mid] = (int(n), sc)
def dfl(p):
    c = zlib.compressobj(9, zlib.DEFLATED, -15); d = open(p, "rb").read()
    return len(c.compress(d) + c.flush())
tot = {"m": 0, "t": 0}
rows = []
for mid, (n, sc) in sorted(cen.items(), key=lambda kv: -kv[1][0]):
    d = os.path.join(WT, "assets/models", mid)
    mj = json.load(open(os.path.join(d, "model.json")))
    lods = mj["model"]["lods"]
    cls = [("/".join(c for c in l["parts"][0]["classes"] if c != "vpbr")) for l in lods]
    mesh = sum(dfl(os.path.join(d, f)) for f in os.listdir(d) if f.endswith(".res"))
    tex = 0   # what the PCK carries: the imported VRAM texture (.ctex) named by the .import file
    for f in os.listdir(d):
        if f.endswith((".webp", ".png")):
            imp = open(os.path.join(d, f + ".import")).read()
            dest = imp.split('dest_files=["res://', 1)[1].split('"', 1)[0]
            tex += dfl(os.path.join(WT, dest))
    tot["m"] += mesh; tot["t"] += tex
    b = rep[mid]["bake"]; a = b["atlas"]
    rows.append("| `%s` | %d | %s | %s / %s | %s / %s | %d×%d | %.1f / %.1f | %d / %d kB | %d s |" % (
        mid.split("/")[1], n, sc.replace("..", "–").replace(".", ","), f"{lods[0]['tris']:,}".replace(",", " "),
        f"{lods[1]['tris']:,}".replace(",", " "), cls[0], cls[1], a[0], a[1], b["ppm_road_min"], b["ppm"],
        round(mesh / 1000), round(tex / 1000), round(rep[mid]["export_s"])))
print("| Set | Platzierungen (Netz) | Maßstab im Spiel | Dreiecke lod0 / lod1 | Klassen lod0 / lod1 | Atlas | px/m Straße min / Packdichte | Archiv Netze / Texturen | Export |")
print("|---|---|---|---|---|---|---|---|---|")
print("\n".join(r.replace(".", ",", 0) for r in rows))
print("\nSumme: Netze %.2f MB, Texturen %.2f MB" % (tot["m"] / 1e6, tot["t"] / 1e6))
