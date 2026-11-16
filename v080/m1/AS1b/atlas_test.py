import sys
import time

import numpy as np
from PIL import Image

sys.path.insert(0, "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-2/tools/blender")
from ce3d import leafatlas as LA  # noqa: E402

OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1b/"
OAK = dict(leaf="lobed", colors=("#2f5a1c", "#466f24", "#3b6420", "#55802c", "#5f8a33"), shade="#16290c",
           n_leaves=430, leaf_len=(0.06, 0.088), fill=0.94, twig="#3a2c1e", twig_share=0.25)
BIRCH = dict(leaf="birch", colors=("#5d8a2a", "#76a03a", "#86ad45", "#6a9632"), shade="#21360f",
             n_leaves=330, leaf_len=(0.05, 0.072), fill=0.92, twig="#4a3a2a", leaf_w=0.62, twig_share=0.35)
GRASS = dict(colors=("#55702c", "#6b8636", "#7d9440", "#4c6628"), shade="#243318", tip="#b4ad6a", n_blades=70)


def scissored(img, bg=(143, 176, 216)):
    a = np.array(img).astype(np.float64)
    vis = a[:, :, 3] >= LA.SCISSOR * 255
    out = np.zeros(a.shape[:2] + (3,))
    out[:] = bg
    out[vis] = a[vis][:, :3]
    return Image.fromarray(out.astype(np.uint8), "RGB")


def mipview(img, level):
    """What the box-filtered mip `level` shows after the scissor, scaled back up."""
    a = np.array(img).astype(np.float64)
    for _ in range(level):
        h, w = a.shape[0] // 2, a.shape[1] // 2
        a = a[:h * 2, :w * 2].reshape(h, 2, w, 2, 4).mean(axis=(1, 3))
    im = scissored(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA"))
    return im.resize((img.width, img.height), Image.NEAREST)


for name, sp in (("oak", OAK), ("birch", BIRCH)):
    t0 = time.time()
    img, rects = LA.atlas(sp, seed=7)
    img.save(OUT + "atlas_%s.png" % name)
    scissored(img).save(OUT + "atlas_%s_sc.jpg" % name)
    cell = img.crop((0, 0, 256, 256))
    strip = Image.new("RGB", (256 * 5, 256))
    for lv in range(5):
        strip.paste(mipview(cell, lv), (lv * 256, 0))
    strip.save(OUT + "mips_%s.jpg" % name)
    print(name, "%.1fs" % (time.time() - t0), "coverage cell0 per mip", LA.coverage(cell, 6))
img, rects = LA.grass_atlas(GRASS)
img.save(OUT + "atlas_grass.png")
scissored(img).save(OUT + "atlas_grass_sc.jpg")
print("grass", LA.coverage(img.crop((0, 0, 256, 256)), 6))
