"""tiles.py <sheet.png> <out.png> <tw>x<th> r,c [r,c ...] [--cols=N] [--scale=s]: pick tiles of a review sheet and
lay them out in a grid (N columns), optionally scaled (nearest)."""
import sys
from PIL import Image
src, out, ts = sys.argv[1], sys.argv[2], sys.argv[3]
tw, th = map(int, ts.split("x"))
cols = 2; scale = 1.0
picks = []
for a in sys.argv[4:]:
    if a.startswith("--cols="): cols = int(a[7:])
    elif a.startswith("--scale="): scale = float(a[8:])
    else:
        r, c = map(int, a.split(",")); picks.append((r, c))
im = Image.open(src).convert("RGB")
rows = (len(picks) + cols - 1) // cols
W, H = int(tw * scale), int(th * scale)
sheet = Image.new("RGB", (W * cols, H * rows), (20, 20, 20))
for i, (r, c) in enumerate(picks):
    t = im.crop((c * tw, r * th, (c + 1) * tw, (r + 1) * th))
    if scale != 1.0: t = t.resize((W, H), Image.NEAREST if scale > 1 else Image.LANCZOS)
    sheet.paste(t, ((i % cols) * W, (i // cols) * H))
sheet.save(out)
print(out, sheet.size)
