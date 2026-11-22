#!/usr/bin/env python3
"""R7c: frame-by-frame look at a Modern clip (AVI of tools/ab_clip.sh KEEP_AVI=1).
clipframes.py <modern.avi> <outdir>
Extracts the frames (scaled to 640x360), computes the share of pixels that change by more than 40 levels from frame to
frame (the picture moves anyway – a level pop shows as a local spike against its neighbours) in the upper 2/3 (the
houses; the HUD corners left out), prints the 8 largest spikes relative to the median of their +-5 neighbours and writes
strips of 4 frames around the 3 largest (pop_<n>.jpg)."""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

avi, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
fdir = os.path.join(out, "frames")
os.makedirs(fdir, exist_ok=True)
subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", avi, "-vf", "scale=640:360", os.path.join(fdir, "f%04d.png")], check=True)
names = sorted(f for f in os.listdir(fdir) if f.endswith(".png"))
prev = None
ch = []
for n in names:
    im = np.asarray(Image.open(os.path.join(fdir, n)).convert("RGB")).astype(np.int16)
    reg = im[20:240, 60:580]
    if prev is not None:
        d = np.abs(reg - prev).max(axis=2) > 40
        ch.append(float(d.mean()))
    prev = reg
ch = np.array(ch)
rel = []
for i in range(len(ch)):
    lo, hi = max(0, i - 5), min(len(ch), i + 6)
    nb = np.concatenate([ch[lo:i], ch[i + 1:hi]])
    med = float(np.median(nb)) if len(nb) else 0.0
    rel.append((ch[i] - med, i, ch[i], med))
rel.sort(reverse=True)
print("FRAMES %d  change median %.2f %%  p95 %.2f %%  max %.2f %%" % (len(names), 100 * np.median(ch), 100 * np.percentile(ch, 95), 100 * ch.max()))
for r in rel[:8]:
    print("SPIKE frame %d->%d  change %.2f %%  neighbours median %.2f %%  excess %.2f %%" % (r[1] + 1, r[1] + 2, 100 * r[2], 100 * r[3], 100 * r[0]))
for k, r in enumerate(rel[:3]):
    i = r[1] + 1
    ims = [Image.open(os.path.join(fdir, names[j])) for j in range(max(0, i - 1), min(len(names), i + 3))]
    strip = Image.new("RGB", (640 * len(ims), 360))
    for j, im in enumerate(ims):
        strip.paste(im, (640 * j, 0))
    strip.save(os.path.join(out, "pop_%d.jpg" % k), quality=85)
np.savetxt(os.path.join(out, "change.txt"), ch, fmt="%.5f")
