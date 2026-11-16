"""Hook patch 6: traffic cars - thinner station lists and 5-point cross-sections for the far levels."""
from patchlib import patch

patch("tools/blender/cesprites/vehicles.py", [
    ('''LOWER_COARSE = (0, 1, 3, 4, 6, 8, 9)          # points of lower_half kept at ring 0
CABIN_COARSE = (0, 1, 2, 3, 5, 7, 8, 9)       # points of cabin_half kept at ring 0
''', '''LOWER_COARSE = (0, 3, 4, 6, 9)                # points of lower_half kept at ring 0
CABIN_COARSE = (0, 1, 2, 5, 9)                # points of cabin_half kept at ring 0


def thin_stations(ys, gap, must=()):
    """Far levels of the 3D models: drops stations closer than gap to the last kept one; the first, the
    last and the stations in `must` (wheel arch edges and centres) always stay."""
    keep = [ys[0]]
    fixed = {round(m, 5) for m in must}
    for y in ys[1:-1]:
        if round(y, 5) in fixed or y - keep[-1] >= gap:
            if round(y, 5) in fixed and y - keep[-1] < gap * 0.35 and round(keep[-1], 5) not in fixed and len(keep) > 1:
                keep[-1] = y
            else:
                keep.append(y)
    if ys[-1] - keep[-1] < gap * 0.35 and len(keep) > 1 and round(keep[-1], 5) not in fixed:
        keep[-1] = ys[-1]
    else:
        keep.append(ys[-1])
    return keep
'''),
    ('''        extra += [p[0] for p in dd["lower"]]
        ys = _stations(y0, y1, 0.08 * k, extra, dense)
        rings = []''', '''        extra += [p[0] for p in dd["lower"]]
        ys = _stations(y0, y1, 0.08 * k, extra, dense)
        if k >= 2.0:
            fs = (-1.0, -0.5, 0.0, 0.5, 1.0) if k < 4.0 else (-1.0, 0.0, 1.0)
            arch = [ya + self.Ra * f for ya in (self.y_ra, self.y_fa) for f in fs]
            ys = thin_stations(sorted(set(ys) | {round(a, 5) for a in arch}), 0.06 * k, arch)
        rings = []'''),
    ('''        ys = _stations(y0, y1, 0.05 * self.detail["step"], [p[0] for p in cab] + [y0 + 0.01, y1 - 0.01])
        rings = []''', '''        ys = _stations(y0, y1, 0.05 * self.detail["step"], [p[0] for p in cab] + [y0 + 0.01, y1 - 0.01])
        if self.detail["step"] >= 2.0:
            ys = thin_stations(ys, 0.05 * self.detail["step"])
        rings = []'''),
    ('''            ys = [y for y in ys if ya <= y <= yb]
            rings = []''', '''            ys = [y for y in ys if ya <= y <= yb]
            if ks >= 2.0:
                ys = thin_stations(ys, 0.05 * ks)
            rings = []'''),
])
