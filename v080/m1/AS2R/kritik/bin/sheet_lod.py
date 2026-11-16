"""LOD swaps of the traffic cars at the swap distances of the three "Details" levels (25/90 Niedrig, 40/120 Mittel,
60/160 Hoch): share of car pixels that change by more than 24 levels (measured), sheet with both levels and the
difference, by day and (40/120) at night."""
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R/kritik/bin")
import klib as K


def pop(a, b, bg):
    A = np.asarray(a).astype(int)
    Bm = np.asarray(b).astype(int)
    G = np.asarray(bg).astype(int)
    car = (np.abs(A - G).max(axis=2) > 10) | (np.abs(Bm - G).max(axis=2) > 10)
    d = np.abs(A - Bm).max(axis=2)
    n = int(car.sum())
    ch = int(((d > 24) & car).sum())
    ys, xs = np.nonzero(car)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1) if len(xs) else (600, 380, 680, 440)
    return n, ch, box, d


def main():
    lines = ["Stufenwechsel (Spielkamera 1280x720, MSAA 2x): Autopixel / davon > 24 Stufen geändert"]
    tiles = []
    e_day = K.tile("empty_day", "t")
    e_night = K.tile("empty_night", "t")
    cases = []
    for car in list(K.TRAFFIC_NEW):
        for d, a, b in ((25, "lod0", "lod1"), (40, "lod0", "lod1"), (60, "lod0", "lod1"), (90, "lod1", "lod2"), (120, "lod1", "lod2"), (160, "lod1", "lod2")):
            cases.append((car, d, a, b, "t", f"{car}_g{d}_{a}_day", f"{car}_g{d}_{b}_day", e_day, "Tag"))
        for d, a, b in ((40, "lod0", "lod1"), (120, "lod1", "lod2")):
            cases.append((car, d, a, b, "x", f"{car}_g{d}_{a}_nightlod", f"{car}_g{d}_{b}_nightlod", e_night, "Nacht"))
    for car in K.TRAFFIC_OLD:
        for d, a, b in ((40, "lod0", "lod1"), (120, "lod1", "lod2")):
            cases.append((car, d, a, b, "t", f"{car}_g{d}_{a}_day", f"{car}_g{d}_{b}_day", e_day, "Tag"))
    for car, d, a, b, batch, na, nb, bg, when in cases:
        if not (K.has_tile(na, batch) and K.has_tile(nb, batch)):
            lines.append(f"  {car:7s} {d:3d} m {a}->{b} {when}: fehlt")
            continue
        ia = K.tile(na, batch)
        ib = K.tile(nb, batch)
        n, ch, box, dmap = pop(ia, ib, bg)
        lines.append(f"  {car:7s} {d:3d} m {a}->{b} {when:5s}: {n:5d} px, {ch:4d} geändert = {100*ch/max(n,1):5.1f} %   (Auto {box[2]-box[0]} x {box[3]-box[1]} px)")
        if d in (40, 120) and car in K.TRAFFIC_NEW:
            pad = 4
            bx = (box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad)
            k = max(2, int(200 / max(1, bx[3] - bx[1])))
            ca = ia.crop(bx).resize(((bx[2] - bx[0]) * k, (bx[3] - bx[1]) * k), Image.NEAREST)
            cb = ib.crop(bx).resize(ca.size, Image.NEAREST)
            dm = Image.fromarray(np.where(dmap > 24, 255, (dmap * 4).clip(0, 120)).astype(np.uint8)).crop(bx).resize(ca.size, Image.NEAREST).convert("RGB")
            tiles += [K.caption(ca, f"{car} {d} m {a} ({when})", 12), K.caption(cb, f"{b}", 12),
                      K.caption(dm, f"Differenz: {100*ch/max(n,1):.1f} % > 24", 12)]
    sheet = K.grid(tiles, 6)
    sheet = K.title(sheet, "Stufenwechsel der neuen Verkehrsautos bei 40 m (lod0 -> lod1) und 120 m (lod1 -> lod2), Spielkamera",
                    sub="ganzzahlig vergrößert, Differenz weiß = mehr als 24 Stufen; Zahlen aller Abstände (25/40/60, 90/120/160 m) in bericht.md")
    print(K.save_jpg(sheet, K.DELIVER + "/13_stufenwechsel.jpg", q=90))
    open(K.OUT + "/lod_pop.txt", "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
