"""AS5a1 scratch: archive share of model folders as pck_report.py estimates it (deflate -9 per file of what the PCK
carries: the .res meshes, the imported .ctex of every texture, model.json), without a build.
   python3 share.py <worktree> <glob of model folders, e.g. props/city_*>"""
import fnmatch
import json
import os
import re
import sys
import zlib

WT, GLOB = sys.argv[1], sys.argv[2]
root = os.path.join(WT, "assets", "models")
rows = []
tot = dict(mesh=0, mesh_z=0, tex=0, tex_z=0, vram=0)
for group in sorted(os.listdir(root)):
    gdir = os.path.join(root, group)
    if not os.path.isdir(gdir):
        continue
    for name in sorted(os.listdir(gdir)):
        mid = group + "/" + name
        if not fnmatch.fnmatch(mid, GLOB):
            continue
        folder = os.path.join(gdir, name)
        r = dict(id=mid, mesh=0, mesh_z=0, tex=0, tex_z=0)
        for f in sorted(os.listdir(folder)):
            p = os.path.join(folder, f)
            if f.endswith(".res") or f == "model.json":
                data = open(p, "rb").read()
                r["mesh"] += len(data)
                r["mesh_z"] += len(zlib.compress(data, 9))
            elif f.endswith((".png", ".webp")):
                imp = p + ".import"
                txt = open(imp).read() if os.path.exists(imp) else ""
                m = re.search(r'path(?:\.s3tc)?="res://(\.godot/imported/[^"]+)"', txt)
                if not m:
                    print("keine importierte Datei für", p)
                    continue
                ctex = os.path.join(WT, m.group(1))
                data = open(ctex, "rb").read()
                r["tex"] += len(data)
                r["tex_z"] += len(zlib.compress(data, 9))
        rows.append(r)
        for k in ("mesh", "mesh_z", "tex", "tex_z"):
            tot[k] += r[k]
MB = 1_000_000.0
print("%-34s %10s %10s %10s %10s" % ("Modell", "Netze B", "Netze z", "Tex PCK", "Tex z"))
for r in rows:
    print("%-34s %10d %10d %10d %10d" % (r["id"], r["mesh"], r["mesh_z"], r["tex"], r["tex_z"]))
print("SUMME Netze %.2f MB (Archiv %.2f MB), Texturen %.2f MB im PCK (Archiv %.2f MB)" % (
    tot["mesh"] / MB, tot["mesh_z"] / MB, tot["tex"] / MB, tot["tex_z"] / MB))
