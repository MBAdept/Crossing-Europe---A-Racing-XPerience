#!/usr/bin/env python3
"""Sets the Godot import parameters of the vehicle sprite sheets to VRAM compression (contract v2 §5).

Usage (after `godot --headless --path . --import` created the .import files):
  python3 tools/blender/set_vram_import.py [--src assets/sprites] [--dry-run]
then run `godot --headless --path . --import` again to re-import.

player/, traffic/, police/ -> compress/mode=2 (VRAM compressed), compress/high_quality=true (BPTC/BC7 on
desktop), mipmaps/generate=true. Showroom, props and UI stay lossless. Also prints the PNG sizes and an
estimate of the GPU memory (BPTC 1 byte/px, lossless RGBA 4 bytes/px, mipmaps +1/3).
"""
import argparse
import os
import re

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
VRAM_DIRS = ("player", "traffic", "police")
WANT = {"compress/mode": "2", "compress/high_quality": "true", "mipmaps/generate": "true"}


def patch_import(path, dry):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    new = text
    for k, v in WANT.items():
        pat = re.compile(r"^%s=.*$" % re.escape(k), re.M)
        if pat.search(new):
            new = pat.sub("%s=%s" % (k, v), new)
        else:
            new = new.replace("[params]\n", "[params]\n\n%s=%s\n" % (k, v), 1)
    if new != text and not dry:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(new)
    return new != text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "assets", "sprites"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    changed = 0
    png_total = 0
    vram = {"vram": 0.0, "lossless": 0.0}
    per_dir = {}
    for d in sorted(os.listdir(args.src)):
        full = os.path.join(args.src, d)
        if not os.path.isdir(full):
            continue
        for f in sorted(os.listdir(full)):
            if not f.endswith(".png"):
                continue
            p = os.path.join(full, f)
            png_total += os.path.getsize(p)
            w, h = Image.open(p).size
            comp = d in VRAM_DIRS
            mem = w * h * (1.0 if comp else 4.0) * (4.0 / 3.0)
            vram["vram" if comp else "lossless"] += mem
            per_dir.setdefault(d, [0, 0.0])
            per_dir[d][0] += os.path.getsize(p)
            per_dir[d][1] += mem
            imp = p + ".import"
            if comp:
                if not os.path.exists(imp):
                    print("fehlt (erst godot --import):", imp)
                    continue
                if patch_import(imp, args.dry_run):
                    changed += 1
    print("%d .import-Dateien geaendert%s" % (changed, " (dry run)" if args.dry_run else ""))
    for d, (b, m) in sorted(per_dir.items()):
        print("  %-9s PNG %6.1f MB   GPU %6.1f MB%s" % (d, b / 1048576.0, m / 1048576.0,
                                                       "  (BPTC)" if d in VRAM_DIRS else ""))
    print("PNG gesamt %.1f MB; GPU-Speicher wenn alles geladen: %.1f MB (Fahrzeuge komprimiert %.1f MB, "
          "Rest verlustfrei %.1f MB)" % (png_total / 1048576.0, (vram["vram"] + vram["lossless"]) / 1048576.0,
                                         vram["vram"] / 1048576.0, vram["lossless"] / 1048576.0))


if __name__ == "__main__":
    main()
