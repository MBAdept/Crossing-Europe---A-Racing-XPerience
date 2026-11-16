#!/usr/bin/env python3
"""Model of the rig's light law for a level surface (all ambient: no moon), before / after the post LUT,
against Arcade's albedo x palette.ambient. Display values 0..255."""
import math


def to_lin(c):
    return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878)


def show(x):
    return max(1.055 * math.pow(max(x, 0.0), 0.416666667) - 0.055, 0.0)


def unshow(d):
    return math.pow((d + 0.055) / 1.055, 2.4) if d > 0 else 0.0


def post_shown(d):
    return show(to_lin(d))


def post_inverse(s):
    if s <= 0:
        return 0.0
    lo, hi = 0.0, 2.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if post_shown(mid) < s:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def law(p, ref, exact, albedos):
    out = {}
    a_ref = to_lin(ref)
    for A in albedos:
        row = []
        for ch in range(3):
            d = (ref * p[ch]) if exact else post_inverse(ref * p[ch])
            amb = unshow(d) / a_ref
            shown = show(to_lin(A) * amb)
            if not exact:
                shown = post_shown(shown)
            row.append(shown * 255)
        out[A] = row
    return out


for name, p in [("N1 22h snow", (0.2033, 0.2522, 0.3576)), ("22h clear (no moon part)", (0.2118, 0.2627, 0.3725)),
                ("19:30", (0.7882, 0.5843, 0.5412))]:
    albedos = [0.12, 0.2, 0.29, 0.38, 0.5, 0.6, 0.75, 0.93]
    print("==", name)
    for ref in (0.29, 0.38, 0.5):
        for exact in (False, True):
            res = law(p, ref, exact, albedos)
            errs = []
            for A in albedos:
                arc = [A * p[ch] * 255 for ch in range(3)]
                e = max((res[A][ch] - arc[ch]) / max(arc[ch], 1e-3) for ch in range(3))
                e2 = min((res[A][ch] - arc[ch]) / max(arc[ch], 1e-3) for ch in range(3))
                errs.append("%+4.0f/%+4.0f" % (e2 * 100, e * 100))
            print("ref %.2f %-6s " % (ref, "LUT" if exact else "today"), " ".join("A%.2f:%s" % (A, s) for A, s in zip(albedos, errs)))
