"""AS3 scratch: silhouette of every tree model and variant (its impostor = orthographic view from the road, the
sprite's own view direction) over the outline of its Arcade sprite, both at 24 px/m, aligned at the anchor and
the ground. Prints the share of the model's silhouette outside the sprite's and writes one overlay sheet.
   python3 outline.py <out.png>"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

WT = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-1"
PPM = 24.0
man = json.load(open(os.path.join(WT, "assets/models/manifest.json")))
spr = json.load(open(os.path.join(WT, "assets/sprites/manifest.json")))["sets"]
species = ["oak", "birch", "beech", "poplar", "olive", "pine", "spruce", "cypress", "palm"]
tiles = []
rows = []
for sp in species:
    sid = "props/tree_" + sp
    s = spr[sid]
    sheet = Image.open(os.path.join(WT, "assets/sprites", s["file"])).convert("RGBA")
    cw, ch = s["cell"]
    cell = np.array(sheet.crop((0, 0, cw, ch))).astype(np.float64) / 255.0
    k = PPM * s["image_width_m"] / cw
    smask = Image.fromarray(((cell[:, :, 3] >= 0.97) * 255).astype(np.uint8)).resize(
        (max(1, int(round(cw * k))), max(1, int(round(ch * k)))), Image.NEAREST)
    s_ax, s_ay = s["anchor"][0] * smask.size[0], s["anchor"][1] * smask.size[1]
    for mid in (sid, sid + "_b"):
        m = man["models"][mid]
        imp = m["impostor"]
        im = Image.open(os.path.join(WT, "assets/models", imp["texture"])).convert("RGBA")
        w_m, h_m = imp["size_m"]
        mmask = im.split()[3].point(lambda a: 255 if a >= 128 else 0).resize(
            (max(1, int(round(w_m * PPM))), max(1, int(round(h_m * PPM)))), Image.NEAREST)
        m_ax, m_ay = imp["anchor_x"] * mmask.size[0], mmask.size[1]
        # common canvas: anchors on one column, ground on one row
        left = int(max(s_ax, m_ax)) + 6
        right = int(max(smask.size[0] - s_ax, mmask.size[0] - m_ax)) + 6
        up = int(max(s_ay, m_ay)) + 6
        W, H = left + right, up + 10
        A = np.zeros((H, W), dtype=bool)
        B = np.zeros((H, W), dtype=bool)
        a = np.array(smask) > 0
        b = np.array(mmask) > 0
        ox, oy = int(round(left - s_ax)), int(round(up - s_ay))
        A[oy:oy + a.shape[0], ox:ox + a.shape[1]] |= a[:max(0, min(a.shape[0], H - oy)), :max(0, min(a.shape[1], W - ox))]
        ox, oy = int(round(left - m_ax)), int(round(up - m_ay))
        B[oy:oy + b.shape[0], ox:ox + b.shape[1]] |= b[:max(0, min(b.shape[0], H - oy)), :max(0, min(b.shape[1], W - ox))]
        # ground row: nothing below it counts (sprite shadows, the trunk foot below the ground)
        A[up + 1:, :] = False
        B[up + 1:, :] = False
        outside = (B & ~A).sum() / max(1, B.sum())
        cover = (A & B).sum() / max(1, A.sum())
        rows.append((mid, outside, cover, int(B.sum()), int(A.sum())))
        img = np.full((H, W, 3), 235, dtype=np.uint8)
        img[B] = (90, 150, 70)
        img[A & ~B] = (200, 215, 235)
        edge = A & ~(np.roll(A, 1, 0) & np.roll(A, -1, 0) & np.roll(A, 1, 1) & np.roll(A, -1, 1))
        img[edge] = (200, 30, 30)
        tile = Image.fromarray(img)
        d = ImageDraw.Draw(tile)
        d.text((4, 4), "%s  %.1f %% außerhalb" % (mid.split("/")[1], 100 * outside), fill=(0, 0, 0))
        tiles.append(tile)
for r in rows:
    print("%-24s Modell außerhalb des Sprite-Umrisses %5.1f %%, Sprite vom Modell gedeckt %5.1f %%" % (r[0], 100 * r[1], 100 * r[2]))
cols = 6
th = max(t.size[1] for t in tiles)
tw = max(t.size[0] for t in tiles)
out = Image.new("RGB", (cols * tw, ((len(tiles) + cols - 1) // cols) * th), (255, 255, 255))
for i, t in enumerate(tiles):
    out.paste(t, ((i % cols) * tw, (i // cols) * th))
out.save(sys.argv[1])
print(sys.argv[1], out.size)
