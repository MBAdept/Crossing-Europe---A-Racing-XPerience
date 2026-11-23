#!/usr/bin/env python3
"""FIX-R7c: Modern goldens R7c (gm_ref) vs FIX-R7c (gm_fix): share of pixels that differ by more than 40 levels, and a
sheet ref | fix | |diff| x 4 per frame."""
import os, sys
import numpy as np
from PIL import Image

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c"
out = sys.argv[1] if len(sys.argv) > 1 else S + "/tmp/gm_sheet.jpg"
rows = []
for f in sorted(os.listdir(S + "/gm_fix")):
    if not f.endswith("_00.png") or "gles" in f:
        continue
    r = S + "/gm_ref/" + f
    if not os.path.exists(r):
        continue
    a = np.asarray(Image.open(r).convert("RGB")).astype(np.int32)
    b = np.asarray(Image.open(S + "/gm_fix/" + f).convert("RGB")).astype(np.int32)
    d = np.abs(a - b).max(axis=2)
    share = 100.0 * float((d > 40).mean())
    anyd = 100.0 * float((d > 0).mean())
    print("%-28s >40: %.2f %%  >0: %.2f %%" % (f, share, anyd))
    diff = np.clip(np.abs(a - b) * 4, 0, 255).astype(np.uint8)
    rows.append(np.concatenate([a.astype(np.uint8), b.astype(np.uint8), diff], axis=1))
if rows:
    sheet = Image.fromarray(np.concatenate(rows, axis=0))
    sheet = sheet.resize((sheet.width // 2, sheet.height // 2))
    sheet.save(out, quality=85)
    print("->", out)
