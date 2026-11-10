#!/usr/bin/env python3
"""How wide can a ruled terrain ribbon (cross-sections perpendicular to the road) be before its points are nearer to
another part of the road (medial axis)? Per side, sampled every 24 m, widths 40..480 m, other parts within 2500 m of
path. (design study v0.8.0)"""
import json, sys, os
import numpy as np
D = sys.argv[1]
R1 = 120.0
idx = json.load(open(os.path.join(D, "index.json")))
widths = [40, 80, 120, 160, 240, 320, 480]
tot = 0
free = {w: 0 for w in widths}
worst = []
for e in idx:
    if e["dev"]:
        continue
    a = np.fromfile(os.path.join(D, e["name"] + ".f32"), dtype=np.float32).reshape(-1, 4)
    seg = e["seg_len"]
    curve = a[:, 0].astype(np.float64)
    n = len(curve)
    kappa = curve / R1
    theta = np.concatenate([[0.0], np.cumsum(kappa * seg)])[:n]
    px = np.concatenate([[0.0], np.cumsum(np.sin(theta + kappa * seg * 0.5) * seg)])[:n]
    pz = np.concatenate([[0.0], np.cumsum(np.cos(theta + kappa * seg * 0.5) * seg)])[:n]
    st = 4
    PX = px[::st]; PZ = pz[::st]; TH = theta[::st]
    m = len(PX)
    step = 2                                   # sample every 24 m
    win = int(2500.0 / (seg * st))
    for i in range(0, m, step):
        lo = max(0, i - win); hi = min(m, i + win + 1)
        wx = PX[lo:hi]; wz = PZ[lo:hi]
        arc = np.abs(np.arange(lo, hi) - i) * seg * st
        nx = np.cos(TH[i]); nz = np.sin(TH[i])       # right vector (x, z) in the python frame (z forward)
        # python frame: forward = (sin th, cos th), right = (cos th, -sin th)
        rx = np.cos(TH[i]); rz = -np.sin(TH[i])
        for side in (-1.0, 1.0):
            tot += 1
            ok_w = 0
            for w in widths:
                qx = PX[i] + side * w * rx; qz = PZ[i] + side * w * rz
                d = np.hypot(wx - qx, wz - qz)
                j = int(np.argmin(d))
                # the nearest road point must be the cross-section's own neighbourhood
                if d[j] < w - 6.0 and arc[j] > 30.0:
                    break
                ok_w = w
            for w in widths:
                if ok_w >= w:
                    free[w] += 1
            if ok_w < 80:
                worst.append((ok_w, e["name"], i * st * seg * e["length_km"] / e["length_z"], abs(curve[min(i * st, n - 1)])))
print("cross-section sides sampled: %d" % tot)
for w in widths:
    print("ruled ribbon %3d m wide is conflict-free on %.2f %% of the sides (not: %d = %.1f km of road side)" % (w, 100.0 * free[w] / tot, tot - free[w], (tot - free[w]) * 24.0 / 1000.0))
worst.sort()
print("narrowest (limit < 80 m): %d samples; examples:" % len(worst))
for wv in worst[:8]:
    print("   limit %3d m  %s km %.1f |curve| %.2f" % wv)
