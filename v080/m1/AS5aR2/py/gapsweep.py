"""AS5aR2: coverage of railings per mip level for different gap alphas (cut_fill) on an existing atlas."""
import sys
import numpy as np
from PIL import Image
B = 16
path = sys.argv[1]
px = np.asarray(Image.open(path), dtype=np.float64)
a0 = px[..., 3] / 255.0
h, w = a0.shape
hb, wb = h // B, w // B
a0 = a0[:hb * B, :wb * B]
gap = np.abs(a0 - 102 / 255.0) < 0.01
print("gap texels", int(gap.sum()))
on = a0 >= 0.5
blocks = on.reshape(hb, B, wb, B).mean(axis=(1, 3))
tx = np.zeros_like(on, dtype=np.float32); tx[:, 1:] = on[:, 1:] != on[:, :-1]
ty = np.zeros_like(on, dtype=np.float32); ty[1:, :] = on[1:, :] != on[:-1, :]
ch = np.maximum(tx.reshape(hb, B, wb, B).sum(axis=(1, 3)), ty.reshape(hb, B, wb, B).sum(axis=(1, 3)))
sel = (blocks > 0.15) & (blocks < 0.85) & (ch >= 24)
ref = float(blocks[sel].mean())
print("blocks", int(sel.sum()), "cov0 %.2f" % ref)
for g in [float(v) for v in sys.argv[2].split(",")]:
    a = np.where(gap, g, a0)
    out = []
    lvl = a
    for k in range(1, 6):
        hh, ww = lvl.shape
        lvl = lvl[:hh // 2 * 2, :ww // 2 * 2].reshape(hh // 2, 2, ww // 2, 2).mean(axis=(1, 3))
        s = max(1, B >> k)
        if (B >> k) == 0:
            break
        cov = (lvl >= 0.5).reshape(hb, s, wb, s).mean(axis=(1, 3))
        out.append("m%d %.2f" % (k, float(cov[sel].mean()) / ref))
    print("g=%.2f  " % g + "  ".join(out))
