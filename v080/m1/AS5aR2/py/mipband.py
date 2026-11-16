"""AS5aR1 scratch: railings of a baked_cutout atlas in the small mip levels (box filter in 8-bit sRGB, as Godot's
Image.generate_mipmaps). Railing blocks as in AS5a1's mipcov.py (16 x 16 texels split by the alpha test, many
transitions). Per mip level:
  cov   share of the railing area passing the alpha test (0.5) / the same at mip 0 (1 = kept, <1 thins, >1 closes)
  dL    seen brightness of the railing area minus that at mip 0, in 8-bit luma: a texel that passes shows its colour,
        one that fails shows the background `bg` (what is behind the railing) - the darkness of the band as the eye
        averages it; 0 = the band keeps its weight
   python3 mipband.py <bg #rrggbb> <albedo.webp|png> [...]"""
import sys

import numpy as np
from PIL import Image

B = 16


def luma(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


bg_hex = sys.argv[1].lstrip("#")
bg = np.array([int(bg_hex[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
L_bg = float(luma(bg))
for path in sys.argv[2:]:
    im = Image.open(path)
    if im.mode != "RGBA":
        print(path, "ohne Alpha (%s)" % im.mode)
        continue
    px = np.asarray(im, dtype=np.float64)
    h, w = px.shape[:2]
    hb, wb = h // B, w // B
    px = px[:hb * B, :wb * B]
    a = px[..., 3] / 255.0
    on = a >= 0.5
    blocks = on.reshape(hb, B, wb, B).mean(axis=(1, 3))
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

    def seen(lv, s):
        al = lv[..., 3] / 255.0
        L = np.where(al >= 0.5, luma(lv[..., :3]), L_bg)
        return L.reshape(hb, s, wb, s).mean(axis=(1, 3)), (al >= 0.5).reshape(hb, s, wb, s).mean(axis=(1, 3))
    L0, c0 = seen(px, B)
    ref_c, ref_L = float(c0[sel].mean()), float(L0[sel].mean())
    out = []
    lvl = px
    for k in range(1, 6):
        hh, ww = lvl.shape[:2]
        lvl = np.round(lvl[:hh // 2 * 2, :ww // 2 * 2].reshape(hh // 2, 2, ww // 2, 2, 4).mean(axis=(1, 3)))
        s = B >> k
        if s < 1:
            break
        Lk, ck = seen(lvl, s)
        out.append("mip%d cov %.2f dL %+5.1f" % (k, float(ck[sel].mean()) / ref_c, float(Lk[sel].mean()) - ref_L))
    print("%s: %d Blöcke, mip0 Deckung %.2f Helligkeit %.1f (Hintergrund %.1f) -> %s" % (
        path.split("/assets/models/")[-1], n, ref_c, ref_L, L_bg, "  ".join(out)))
