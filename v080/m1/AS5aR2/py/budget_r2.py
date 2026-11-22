"""AS5aR2: budget table of the 23 city models (German number format): tris lod0/lod1, classes, atlas, px/m road min /
max / packing ppm, archive meshes/textures (deflate -9 as pck_report), export time.
   python3 budget_r2.py <worktree>"""
import json
import os
import sys
import zlib

WT = sys.argv[1]
rep = json.load(open(os.path.join(WT, "tools/blender/_cache3d/export_report.json")))
ORDER = ["french_sud", "belgian_terrace", "french_maison", "french_immeuble", "dutch_terrace", "belgian_stone",
         "paris_haussmann", "swiss_chalet", "dutch_canal", "swiss_laube", "dutch_canal_b", "paris_corner",
         "german_house", "german_mietshaus", "german_gruenderzeit", "german_office", "german_old_fachwerk",
         "german_old_fachwerk_b", "german_old_barock", "hanse_gabled", "hanse_kontor", "hanse_speicher", "hanse_crane"]


def de(v, nd=0):
    s = ("%." + str(nd) + "f") % v
    if nd == 0:
        s = "{:,}".format(int(round(v))).replace(",", " ")
    return s.replace(".", ",")


def ctex_bytes(folder, name):
    imp = os.path.join(folder, name + ".import")
    for line in open(imp):
        if line.startswith("path") and ".ctex" in line:
            p = line.split("=", 1)[1].strip().strip('"').replace("res://", "")
            p = os.path.join(WT, p)
            if os.path.exists(p):
                d = open(p, "rb").read()
                return len(d), len(zlib.compress(d, 9))
    return 0, 0


tot = [0, 0, 0, 0]
print("| Set | Dreiecke lod0 / lod1 | Klassen lod0 / lod1 | Atlas | px/m Straße min / Packdichte | Archiv Netze / Texturen | Export |")
print("|---|---|---|---|---|---|---|")
for n in ORDER:
    mid = "props/city_" + n
    folder = os.path.join(WT, "assets/models", mid)
    mj = json.load(open(os.path.join(folder, "model.json")))["model"]
    lods = mj["lods"]
    tris = " / ".join(de(l["tris"]) for l in lods)
    cls = " / ".join("+".join(c for c in l["parts"][0]["classes"] if c != "vpbr") for l in lods)
    mesh_z = 0
    for f in os.listdir(folder):
        if f.endswith(".res") or f == "model.json":
            mesh_z += len(zlib.compress(open(os.path.join(folder, f), "rb").read(), 9))
    tex_z = 0
    for f in os.listdir(folder):
        if f.endswith((".png", ".webp")):
            tex_z += ctex_bytes(folder, f)[1]
    r = rep.get(mid, {})
    b = r.get("bake", {})
    from PIL import Image
    alb = [f for f in os.listdir(folder) if f.startswith("albedo") and not f.endswith(".import")][0]
    w, h = Image.open(os.path.join(folder, alb)).size
    tot[0] += mesh_z
    tot[1] += tex_z
    if n.startswith(("german", "hanse")):
        tot[3] += tex_z
        tot[2] += mesh_z
    print("| `city_%s` | %s | %s | %d×%d | %s / %s | %s / %s kB | %s s |" % (
        n, tris, cls, w, h, de(b.get("ppm_road_min", 0), 1), de(b.get("ppm", 0), 1), de(mesh_z / 1000.0),
        de(tex_z / 1000.0), de(r.get("build_s", 0))))
b2m, b2t = tot[0] - tot[2], tot[1] - tot[3]
print()
print("Charge 2: Netze %s MB, Texturen %s MB; Charge 1: Netze %s MB, Texturen %s MB (Archiv, deflate -9)" % (
    de(b2m / 1e6, 2), de(b2t / 1e6, 2), de(tot[2] / 1e6, 2), de(tot[3] / 1e6, 2)))
