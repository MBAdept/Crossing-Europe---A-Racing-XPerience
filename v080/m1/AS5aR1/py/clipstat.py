"""clipstat.py <clipdir> [<swap log>]: per-frame mean absolute change (luma, 0..255) of the whole frame and its
'temporal roughness' (mean |I(t+1) - 2 I(t) + I(t-1)| over pixels whose luma changes at all). Swap frames from the
log (SWAP fNNN ...) are compared with the median of the other frames: pop = MAD(swap) / median MAD."""
import sys, glob, re, os
import numpy as np
from PIL import Image
d = sys.argv[1]
files = sorted(glob.glob(os.path.join(d, "f_*.png")))
lum = [np.asarray(Image.open(f).convert("L"), dtype=np.float32) for f in files]
mad = [0.0] + [float(np.mean(np.abs(lum[i] - lum[i - 1]))) for i in range(1, len(lum))]
diffs = [None] + [np.abs(lum[i] - lum[i - 1]) for i in range(1, len(lum))]
pop = [0, 0] + [int(np.count_nonzero(diffs[i] > diffs[i - 1] + 20.0)) for i in range(2, len(lum))]
rough = []
for i in range(1, len(lum) - 1):
    sd = np.abs(lum[i + 1] - 2 * lum[i] + lum[i - 1])
    rough.append(float(np.mean(sd)))
swaps = {}
log = sys.argv[2] if len(sys.argv) > 2 else os.path.join(d, "f.log")
if os.path.exists(log):
    for line in open(log):
        m = re.match(r"SWAP f(\d+) (\S+) (\S+)", line)
        if m:
            swaps.setdefault(int(m.group(1)), []).append(m.group(2) + " " + m.group(3))
others = [mad[i] for i in range(2, len(mad)) if i not in swaps]
med = float(np.median(others)) if others else 0.0
pothers = [pop[i] for i in range(2, len(pop)) if i not in swaps]
pmed = float(np.median(pothers)) if pothers else 0.0
print("CLIP %s frames %d  MAD median %.2f  roughness mean %.2f p95 %.2f  pop-px median %d p95 %d" % (os.path.basename(d.rstrip('/')), len(files), med, np.mean(rough), np.percentile(rough, 95), pmed, np.percentile(pothers, 95) if pothers else 0))
for f in sorted(swaps):
    if f < len(mad):
        print("  swap f%03d pop-px %d (x%.1f of median, %.2f %% of the frame)  %s" % (f, pop[f], pop[f] / max(pmed, 1.0), 100.0 * pop[f] / lum[0].size, "; ".join(swaps[f])))
