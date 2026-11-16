"""Smooth 1-D curves for the procedural car bodies (pure Python + numpy, no bpy).

Profile    monotone piecewise cubic (Fritsch-Carlson PCHIP) through knots: no overshoot, C1, flat at
           local extrema - the side-view lines, plan-view widths and section curves are built from it.
round_end  inset of a rounded end (circle or superellipse) - plan corners, roof edges, bumper ends.
stations   sample positions along an axis, densified near ends and around given features.
"""
import math

import numpy as np


class Profile:
    """Monotone cubic Hermite interpolant through [(x, y), ...]; constant beyond the end knots.
    slopes: optional {knot index: dy/dx} to pin tangents (e.g. 0 for a flat start)."""

    def __init__(self, pts, slopes=None):
        pts = sorted((float(a), float(b)) for a, b in pts)
        self.x = np.array([p[0] for p in pts])
        self.y = np.array([p[1] for p in pts])
        n = len(pts)
        if n < 2:
            self.x = np.array([0.0, 1.0])
            self.y = np.array([pts[0][1], pts[0][1]])
            n = 2
        h = np.diff(self.x)
        h[h == 0] = 1e-9
        delta = np.diff(self.y) / h
        d = np.zeros(n)
        if n == 2:
            d[:] = delta[0]
        else:
            for k in range(1, n - 1):
                if delta[k - 1] * delta[k] <= 0.0:
                    d[k] = 0.0
                else:
                    w1 = 2.0 * h[k] + h[k - 1]
                    w2 = h[k] + 2.0 * h[k - 1]
                    d[k] = (w1 + w2) / (w1 / delta[k - 1] + w2 / delta[k])
            d[0] = _end_slope(h[0], h[1], delta[0], delta[1])
            d[-1] = _end_slope(h[-1], h[-2], delta[-1], delta[-2])
        for i, s in (slopes or {}).items():
            d[i] = s
        self.d = d
        self.h = h

    def __call__(self, x):
        scalar = np.isscalar(x)
        xa = np.atleast_1d(np.asarray(x, dtype=np.float64))
        xc = np.clip(xa, self.x[0], self.x[-1])
        k = np.clip(np.searchsorted(self.x, xc, side="right") - 1, 0, len(self.x) - 2)
        h = self.h[k]
        t = (xc - self.x[k]) / h
        t2, t3 = t * t, t * t * t
        y = ((2 * t3 - 3 * t2 + 1) * self.y[k] + (t3 - 2 * t2 + t) * h * self.d[k] +
             (-2 * t3 + 3 * t2) * self.y[k + 1] + (t3 - t2) * h * self.d[k + 1])
        return float(y[0]) if scalar else y

    def deriv(self, x, eps=1e-4):
        return (self(x + eps) - self(x - eps)) / (2 * eps)


def _end_slope(h0, h1, d0, d1):
    s = ((2 * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
    if s * d0 <= 0:
        return 0.0
    if d0 * d1 <= 0 and abs(s) > abs(3 * d0):
        return 3 * d0
    return s


def P(pts, **kw):
    return Profile(pts, **kw)


def const(v):
    return Profile([(0.0, v), (1.0, v)])


def round_end(d, r, p=2.0):
    """Inset of a rounded end of radius r at distance d from the end (0 for d >= r).
    p = 2: quarter circle; p > 2: squarer superellipse corner."""
    if r <= 0.0 or d >= r:
        return 0.0
    d = max(d, 0.0)
    q = (r - d) / r
    return r - r * (1.0 - q ** p) ** (1.0 / p)


def smoothstep(e0, e1, x):
    if e1 == e0:
        return 1.0 if x >= e1 else 0.0
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def bump(x, c, w):
    """Cosine bump: 1 at c, 0 beyond |x - c| >= w."""
    if w <= 0 or abs(x - c) >= w:
        return 0.0
    return 0.5 * (1.0 + math.cos(math.pi * (x - c) / w))


def lerp(a, b, t):
    return a + (b - a) * t


def stations(y0, y1, step, ends=((0.0, 0), (0.0, 0)), features=(), dense=()):
    """Sorted sample positions in [y0, y1].
    step      base spacing
    ends      ((r0, n0), (r1, n1)): n stations cosine-clustered within r of each end
    features  exact positions to include
    dense     [(a, b, step)] extra spacing inside ranges"""
    ys = set()
    n = max(2, int(math.ceil((y1 - y0) / step)))
    for i in range(n + 1):
        ys.add(round(y0 + (y1 - y0) * i / n, 6))
    (r0, n0), (r1, n1) = ends
    for i in range(1, n0 + 1):
        ys.add(round(y0 + r0 * (1 - math.cos(0.5 * math.pi * i / n0)), 6))
    for i in range(1, n1 + 1):
        ys.add(round(y1 - r1 * (1 - math.cos(0.5 * math.pi * i / n1)), 6))
    for f in features:
        if y0 <= f <= y1:
            ys.add(round(f, 6))
    for (a, b, st) in dense:
        a, b = max(a, y0), min(b, y1)
        if b <= a:
            continue
        k = max(1, int(math.ceil((b - a) / st)))
        for i in range(k + 1):
            ys.add(round(a + (b - a) * i / k, 6))
    out = sorted(ys)
    # drop near-duplicates (< 0.4 mm) that would create sliver faces
    res = [out[0]]
    for v in out[1:]:
        if v - res[-1] > 0.0004:
            res.append(v)
    if res[-1] != out[-1]:
        res[-1] = out[-1]
    return res


def spacing(n, kind="cos", a=0.0, b=1.0):
    """n+1 parameters from a to b: 'lin', 'cos' (dense at both ends), 'start'/'end' (dense at one end)."""
    out = []
    for i in range(n + 1):
        t = i / n
        if kind == "cos":
            t = 0.5 - 0.5 * math.cos(math.pi * t)
        elif kind == "start":
            t = 1 - math.cos(0.5 * math.pi * t)
        elif kind == "end":
            t = math.sin(0.5 * math.pi * t)
        out.append(a + (b - a) * t)
    return out


def bezier(p0, p1, p2, p3, n, include_start=True):
    """Cubic Bezier in 2-D, n segments."""
    out = []
    for i in range(0 if include_start else 1, n + 1):
        t = i / n
        u = 1 - t
        out.append((u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                    u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]))
    return out


def arc(cx, cy, r, a0, a1, n, include_start=True, rx=None, ry=None):
    """Elliptic arc points (degrees)."""
    rx = r if rx is None else rx
    ry = r if ry is None else ry
    out = []
    for i in range(0 if include_start else 1, n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        out.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return out


def polyline_length(pts):
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts[:-1], pts[1:]))


def resample(pts, n):
    """Resamples an open 2-D polyline to n+1 points evenly spaced by arc length."""
    seg = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts[:-1], pts[1:])]
    total = sum(seg) or 1e-9
    out = [pts[0]]
    acc = 0.0
    k = 0
    for i in range(1, n):
        target = total * i / n
        while k < len(seg) - 1 and acc + seg[k] < target:
            acc += seg[k]
            k += 1
        t = (target - acc) / (seg[k] or 1e-9)
        a, b = pts[k], pts[k + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    out.append(pts[-1])
    return out


def offset_polyline(pts, d):
    """Offsets an open 2-D polyline sideways by d (left = positive)."""
    out = []
    n = len(pts)
    for i in range(n):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, ty) or 1e-9
        out.append((pts[i][0] - ty / ln * d, pts[i][1] + tx / ln * d))
    return out


def stroke(pts, width, cap=True):
    """Closed outline (counter-clockwise) of a polyline stroked with the given width."""
    left = offset_polyline(pts, width / 2)
    right = offset_polyline(pts, -width / 2)
    return left + list(reversed(right))


def rounded_rect(cx, cy, w, h, r, n=5):
    """Counter-clockwise rounded rectangle (full width w, height h)."""
    r = max(0.0, min(r, w / 2 - 1e-5, h / 2 - 1e-5))
    pts = []
    for (x, y, a0) in ((cx + w / 2 - r, cy - h / 2 + r, -90), (cx + w / 2 - r, cy + h / 2 - r, 0),
                       (cx - w / 2 + r, cy + h / 2 - r, 90), (cx - w / 2 + r, cy - h / 2 + r, 180)):
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((x + r * math.cos(a), y + r * math.sin(a)))
    return pts


def ellipse(cx, cy, rx, ry, n=32, rot=0.0):
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def poly_area(pts):
    a = 0.0
    for i in range(len(pts)):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % len(pts)]
        a += x0 * y1 - x1 * y0
    return a * 0.5


def ccw(pts):
    return list(pts) if poly_area(pts) >= 0 else list(reversed(pts))


def smooth_closed(pts, n_per_seg=6, tension=0.5):
    """Closed Catmull-Rom spline through the points (rounded outlines from a few control points)."""
    out = []
    m = len(pts)
    for i in range(m):
        p0, p1, p2, p3 = pts[(i - 1) % m], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
        for k in range(n_per_seg):
            t = k / n_per_seg
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                       (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    return out


def smooth_open(pts, n_per_seg=6):
    """Open Catmull-Rom spline through the points (end points duplicated)."""
    ext = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(n_per_seg):
            t = k / n_per_seg
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 +
                       (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    out.append(tuple(pts[-1]))
    return out
