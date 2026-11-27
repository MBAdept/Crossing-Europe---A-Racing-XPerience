#!/usr/bin/env python3
"""W6 scratch: table of the AS6 landmark models for docs/modelle.md section 24 (export report, model.json, deflate -9
of the mesh files and the imported .ctex like tools/pck_report.py, height/placements from data/cities.json)."""
import json, os, sys, zlib
WT = sys.argv[1]
rep = json.load(open(os.path.join(WT, "tools/blender/_cache3d/export_report.json")))
cities = json.load(open(os.path.join(WT, "data/cities.json")))
names = {c["id"]: c["name"] for c in json.load(open(os.path.join(WT, "data/network.json")))["cities"]}
sys.path.insert(0, os.path.join(WT, "tools/blender"))
used = {}
for city, v in cities["cities"].items():
    for lm in v.get("landmarks", []):
        used.setdefault(lm["set"], []).append(city)
    for sk in v.get("skyline", []):
        sid = sk if isinstance(sk, str) else sk["set"]
        used.setdefault(sid, [])
def dfl(p):
    c = zlib.compressobj(9, zlib.DEFLATED, -15); d = open(p, "rb").read()
    return len(c.compress(d) + c.flush())
order = sys.argv[2].split(",")
tot = [0, 0]
print("| Wahrzeichen | Städte | Höhe | Dreiecke | Atlas | Packdichte | vpbr | Archiv Netz / Texturen | Export |")
print("|---|---|---|---|---|---|---|---|---|")
for name in order:
    mid = "landmarks/" + name
    d = os.path.join(WT, "assets/models", mid)
    if not os.path.isdir(d):
        print("| `%s` | – fehlt – |" % name); continue
    mj = json.load(open(os.path.join(d, "model.json")))
    tris = mj["model"]["lods"][0]["tris"]
    classes = mj["model"]["lods"][0]["parts"][0]["classes"]
    mesh = sum(dfl(os.path.join(d, f)) for f in os.listdir(d) if f.endswith(".res"))
    tex = 0
    for f in os.listdir(d):
        if f.endswith((".webp", ".png")):
            imp = open(os.path.join(d, f + ".import")).read()
            dest = imp.split('dest_files=["res://', 1)[1].split('"', 1)[0]
            tex += dfl(os.path.join(WT, dest))
    tot[0] += mesh; tot[1] += tex
    e = rep.get(mid, {}); b = e.get("bake", {})
    a = b.get("atlas", ["?", "?"])
    h = cities["landmark_sets"].get(mid, {}).get("height_m") or round(mj["model"]["object"]["height_m"])
    cs = sorted(set(used.get(mid, [])))
    print("| `%s` | %s | %s m | %s | %s×%s | %s px/m | %s | %d / %d kB | %d s |" % (
        name, ", ".join(names.get(c, c) for c in sorted(cs, key=lambda c: names.get(c, c))) or "–", str(h).replace(".", ","), f"{tris:,}".replace(",", " "),
        a[0], a[1], str(b.get("ppm", "?")).replace(".", ","), "ja" if "vpbr" in classes else "–",
        round(mesh / 1000), round(tex / 1000), round(e.get("export_s", 0))))
print("\nSumme: Netze %.2f MB, Texturen %.2f MB" % (tot[0] / 1e6, tot[1] / 1e6))
