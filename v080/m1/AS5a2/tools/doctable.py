"""AS5a2 scratch: the docs table of section 21 (German number format) from model.json, the export report and the
archive estimate (deflate -9 of .res/model.json and of the imported .ctex, as share.py).
   python3 doctable.py <worktree>"""
import json
import os
import re
import sys
import zlib

WT = sys.argv[1]
ROWS = [("props/city_french_sud", 588), ("props/city_belgian_terrace", 315), ("props/city_french_maison", 209),
        ("props/city_french_immeuble", 202), ("props/city_dutch_terrace", 130), ("props/city_belgian_stone", 96),
        ("props/city_paris_haussmann", 55), ("props/city_swiss_chalet", 54), ("props/city_dutch_canal", 51),
        ("props/city_swiss_laube", 46), ("props/city_dutch_canal_b", 22), ("props/city_paris_corner", 8)]
rep = json.load(open(os.path.join(WT, "tools/blender/_cache3d/export_report.json")))


def de(x, nd=0):
    s = ("%." + str(nd) + "f") % x
    s = s.replace(".", ",")
    if nd == 0 and abs(x) >= 1000:
        s = "{:,}".format(int(round(x))).replace(",", " ")
    return s


def ctex_of(p):
    txt = open(p + ".import").read() if os.path.exists(p + ".import") else ""
    m = re.search(r'path(?:\.s3tc)?="res://(\.godot/imported/[^"]+)"', txt)
    if not m:
        return None
    q = os.path.join(WT, m.group(1))
    return q if os.path.exists(q) else None


print("| Set | Platzierungen (Netz) | Dreiecke lod0 / lod1 | Atlas | px/m Straßenwand (Modellmaß) | Archiv Netze / Texturen | Backzeit |")
print("|---|---|---|---|---|---|---|")
tm = tt = 0
for mid, n in ROWS:
    folder = os.path.join(WT, "assets/models", mid)
    m = json.load(open(os.path.join(folder, "model.json")))["model"]
    tris = " / ".join(de(l["tris"]) for l in m["lods"])
    r = rep.get(mid, {})
    b = r.get("bake", {})
    mz = tz = 0
    for f in sorted(os.listdir(folder)):
        p = os.path.join(folder, f)
        if f.endswith(".res") or f == "model.json":
            mz += len(zlib.compress(open(p, "rb").read(), 9))
        elif f.endswith((".png", ".webp")):
            q = ctex_of(p)
            if q:
                tz += len(zlib.compress(open(q, "rb").read(), 9))
    tm += mz
    tt += tz
    print("| `%s` | %d | %s | %s | %s–%s | %d / %d kB | %s s |" % (
        mid.split("/")[1], n, tris, "×".join(str(v) for v in b.get("atlas", [])),
        de(b.get("ppm_road_min", 0)), de(b.get("ppm_road_max", 0)), round(mz / 1000), round(tz / 1000),
        de(r.get("build_s", 0))))
print()
print("SUMME Archiv: Netze %s MB, Texturen %s MB" % (de(tm / 1e6, 2), de(tt / 1e6, 2)))
