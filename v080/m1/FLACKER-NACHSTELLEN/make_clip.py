#!/usr/bin/env python3
"""FLACKER-NACHSTELLEN: side-by-side clip (fixed 60 fps) of probe_switch2.gd clip runs.

Each input = "label|run dir" (the c####.png crops of its first set). Frames are put next to each other, a label and the
per-frame state (distance, level) under each; written as PNGs into a temp dir and encoded with ffmpeg (H.264, 60 fps).
Also writes a still strip of selected frames (--strip=k1,k2,...).

usage: make_clip.py <out.mp4> "label|run" ["label|run" ...] [--scale=1.0] [--strip=out.png:1,30,60]
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont


def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def rows_of(run):
    out = {}
    for line in open(os.path.join(run, "log.jsonl")):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if d.get("phase") == "clip":
            out[d["i"]] = d
    return out


def main():
    out = sys.argv[1]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    ins = [a.split("|") for a in sys.argv[2:] if not a.startswith("--")]
    scale = float(opts.get("scale", "1.0"))
    srcs = []
    for label, run in ins:
        sets = [d for d in sorted(os.listdir(run)) if os.path.isdir(os.path.join(run, d))]
        sd = os.path.join(run, sets[0])
        srcs.append((label, sd, rows_of(run)))
    n = min(len(r) for _, _, r in srcs)
    tmp = tempfile.mkdtemp(prefix="clip_", dir=os.path.dirname(os.path.abspath(out)))
    f = font(18)
    fs = font(15)
    first = Image.open(os.path.join(srcs[0][1], "c0001.png"))
    w, h = int(first.width * scale), int(first.height * scale)
    frames = []
    for i in range(1, n + 1):
        canvas = Image.new("RGB", (len(srcs) * (w + 6) + 6, h + 62), (20, 20, 20))
        dr = ImageDraw.Draw(canvas)
        for k, (label, sd, rows) in enumerate(srcs):
            im = Image.open(os.path.join(sd, "c%04d.png" % i)).convert("RGB")
            if scale != 1.0:
                im = im.resize((w, h), Image.LANCZOS)
            x = 6 + k * (w + 6)
            canvas.paste(im, (x, 28))
            dr.text((x, 4), label, fill=(255, 230, 120), font=f)
            r = rows.get(i, {})
            st = "Bild %d  Abstand %.1f m  %s" % (i, r.get("cd", r.get("d", 0)) if r.get("cd", -1) >= 0 else r.get("d", 0),
                                                 r.get("lod", "") or "")
            dr.text((x, h + 34), st, fill=(210, 210, 210), font=fs)
        p = os.path.join(tmp, "v%04d.png" % i)
        canvas.save(p)
        frames.append(p)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "60", "-i", os.path.join(tmp, "v%04d.png"),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", out], check=True)
    if "strip" in opts:
        sp, ks = opts["strip"].split(":")
        ks = [int(k) for k in ks.split(",")]
        ims = [Image.open(frames[k - 1]) for k in ks if k <= len(frames)]
        strip = Image.new("RGB", (ims[0].width, sum(i.height for i in ims)), (20, 20, 20))
        y = 0
        for im in ims:
            strip.paste(im, (0, y))
            y += im.height
        strip.save(sp)
    shutil.rmtree(tmp)
    print("clip", out, n, "frames")


if __name__ == "__main__":
    main()
