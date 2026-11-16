#!/usr/bin/env python3
"""QA-M2-BILD: single frames and a frame-to-frame change curve of an A/B clip (tools/ab_clip.sh: Arcade left, Modern
right, each with a label strip on top).
usage: clipframes.py <clip.mp4> <out_dir> <t1,t2,...>
Writes <out_dir>/<name>_tNN.jpg (both halves) for the given seconds, and prints per half the 10 largest
frame-to-frame changes in the scenery band (rows 25–60 % of the picture, i.e. above the player car and below the HUD
strip) – a pop (LOD swap, a prop appearing) shows as a spike over the motion level (median)."""
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

clip, out, times = sys.argv[1], sys.argv[2], [float(t) for t in sys.argv[3].split(",")]
os.makedirs(out, exist_ok=True)
name = os.path.splitext(os.path.basename(clip))[0]
for t in times:
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % t, "-i", clip, "-frames:v", "1", "-q:v", "3",
                    os.path.join(out, "%s_t%04.1f.jpg" % (name, t))], check=True)
tmp = tempfile.mkdtemp()
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", clip, "-vf", "scale=640:-2", os.path.join(tmp, "%05d.png")], check=True)
files = sorted(os.listdir(tmp))
prev = None
diffs = {"arcade": [], "modern": []}
for f in files:
    im = np.asarray(Image.open(os.path.join(tmp, f)).convert("L")).astype(np.float32)
    h, w = im.shape
    halves = {"arcade": im[:, : w // 2], "modern": im[:, w // 2:]}
    if prev is not None:
        for k in halves:
            a = halves[k]
            b = prev[k]
            hh = a.shape[0]
            band = slice(int(hh * 0.25), int(hh * 0.60))
            diffs[k].append(float(np.abs(a[band] - b[band]).mean()))
    prev = halves
for f in files:
    os.remove(os.path.join(tmp, f))
os.rmdir(tmp)
for k, d in diffs.items():
    d = np.array(d)
    if d.size == 0:
        continue
    med = np.median(d)
    top = np.argsort(d)[-10:][::-1]
    print("%s: frames %d, median change %.2f, p95 %.2f, max %.2f; spikes > 3x median: %d" % (
        k, d.size, med, np.percentile(d, 95), d.max(), int((d > 3 * med).sum())))
    print("   largest at t=" + ", ".join("%.2f s (%.1f)" % ((i + 1) / 60.0, d[i]) for i in top))
