"""swappop.py <clipdir> <manifest.json> [scale overrides name=sc ...]: for every SWAP line of <clipdir>/f.log the
screen rectangle of that building (game camera: 3.4 m high, focal 711 px, principal point 640/324) and inside it
the share of pixels whose change from the frame before is larger than in the step before by > 20 luma ("pop"),
compared with the same share for the steps around it (median of f-6..f-2 and f+2..f+6)."""
import sys, os, re, json
import numpy as np
from PIL import Image
d = sys.argv[1]
man = json.load(open(sys.argv[2]))
scales = {kv.split("=")[0]: float(kv.split("=")[1]) for kv in sys.argv[3:]}
lum = {}
def L(i):
    if i not in lum:
        p = os.path.join(d, "f_%03d.png" % i)
        lum[i] = np.asarray(Image.open(p).convert("L"), dtype=np.float32) if os.path.exists(p) else None
    return lum[i]
def pop(i, box):
    a, b, c = L(i - 2), L(i - 1), L(i)
    if a is None or b is None or c is None:
        return None
    x0, y0, x1, y1 = box
    d1 = np.abs(b[y0:y1, x0:x1] - a[y0:y1, x0:x1])
    d2 = np.abs(c[y0:y1, x0:x1] - b[y0:y1, x0:x1])
    return float(np.mean(d2 > d1 + 20.0)) * 100.0, float(np.mean(np.abs(c[y0:y1, x0:x1] - b[y0:y1, x0:x1])))
for line in open(os.path.join(d, "f.log")):
    m = re.match(r"SWAP f(\d+) (\S+) (\S+) d=([\d.]+) x=(-?[\d.]+)", line)
    if not m:
        continue
    f, name, what, dist, x = int(m.group(1)), m.group(2), m.group(3), float(m.group(4)), float(m.group(5))
    mod = man["models"]["props/" + name]
    bb = mod["aabb"]
    sc = scales.get(name, 1.0)
    xs = [x + (-v if x < 0 else v) * sc for v in (bb[0], bb[3])]
    zs = [dist - bb[5] * sc, dist - bb[2] * sc]    # depth of front and back face
    ys = [bb[1] * sc, bb[4] * sc]
    pts = []
    for X in xs:
        for D in zs:
            for Y in ys:
                if D > 1.0:
                    pts.append((640 + 711 * X / D, 324 - 711 * (Y - 3.4) / D))
    px = [p[0] for p in pts]; py = [p[1] for p in pts]
    box = (max(0, int(min(px))), max(0, int(min(py))), min(1280, int(max(px)) + 1), min(720, int(max(py)) + 1))
    if box[2] - box[0] < 4 or box[3] - box[1] < 4:
        continue
    at = pop(f, box)
    ref = [pop(i, box) for i in list(range(f - 6, f - 1)) + list(range(f + 2, f + 7))]
    ref = [r for r in ref if r is not None]
    if at is None or not ref:
        continue
    rp = float(np.median([r[0] for r in ref])); rm = float(np.median([r[1] for r in ref]))
    print("SWAPPOP f%03d %-28s %s d=%.0f box %dx%d: pop %.1f %% of the box (around %.1f %%), mean change %.1f (around %.1f)"
          % (f, name, what, dist, box[2] - box[0], box[3] - box[1], at[0], rp, at[1], rm))
