"""AS5a1 scratch: coverage of the cut-out railings in the small mip levels of a baked_cutout atlas.
   python3 mipcov.py <albedo.png> [...]
Blocks of 16 x 16 texels where the alpha test splits the block (between 15 % and 85 % of the texels pass) are the
railing (bars and the gaps between them; walls are opaque, the empty atlas is transparent). Per mip level (box
filter, as Image.generate_mipmaps) the share of the railing area that passes the alpha test (0.5) is compared with
mip 0: 1.0 = the railing keeps its coverage, < 1 thins out / vanishes, > 1 closes up. A pixel at mip k is counted
for the share of the block it covers."""
import sys

import numpy as np
from PIL import Image

B = 16
for path in sys.argv[1:]:
    im = Image.open(path)
    if im.mode != "RGBA":
        print(path, "ohne Alpha (%s)" % im.mode)
        continue
    a = np.asarray(im, dtype=np.float32)[:, :, 3] / 255.0
    h, w = a.shape
    hb, wb = h // B, w // B
    a = a[:hb * B, :wb * B]
    on = a >= 0.5
    blocks = on.reshape(hb, B, wb, B).mean(axis=(1, 3))
    # bars, not chart borders: a straight border crosses each row of a block once (16 changes), bars several times
    tx = np.zeros_like(on, dtype=np.float32)
    tx[:, 1:] = on[:, 1:] != on[:, :-1]
    ty = np.zeros_like(on, dtype=np.float32)
    ty[1:, :] = on[1:, :] != on[:-1, :]
    ch = np.maximum(tx.reshape(hb, B, wb, B).sum(axis=(1, 3)), ty.reshape(hb, B, wb, B).sum(axis=(1, 3)))
    sel = (blocks > 0.15) & (blocks < 0.85) & (ch >= 24)
    n = int(sel.sum())
    if n == 0:
        print(path, "keine Geländerblöcke")
        continue
    ref = float(blocks[sel].mean())
    out = []
    lvl = a
    for k in range(1, 5):
        hh, ww = lvl.shape
        lvl = lvl[:hh // 2 * 2, :ww // 2 * 2].reshape(hh // 2, 2, ww // 2, 2).mean(axis=(1, 3))
        s = B >> k
        cov = (lvl >= 0.5).reshape(hb, s, wb, s).mean(axis=(1, 3))
        mean_a = lvl.reshape(hb, s, wb, s).mean(axis=(1, 3))
        out.append("mip%d %.2f (Alpha-Mittel %.2f)" % (k, float(cov[sel].mean()) / ref, float(mean_a[sel].mean())))
    print("%s: %d Blöcke à %d², Deckung mip0 %.2f -> %s" % (path.split("/assets/models/")[-1], n, B, ref, "  ".join(out)))
