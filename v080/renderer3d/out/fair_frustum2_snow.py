#!/usr/bin/env python3
"""Fairness part 1b: the cases where Arcade has a vehicle on screen and true 3D (look-into-curve camera) has not:
how far is the stopping sight distance at the fastest drivable speed there? (design study v0.8.0)"""
import json, sys, os
import numpy as np
D = sys.argv[1]
R1 = 120.0
F = 640.0 / np.tan(np.radians(42.0))
HALF = 640.0
GAIN, LOOK = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6, float(sys.argv[3]) if len(sys.argv) > 3 else 100.0
idx = json.load(open(os.path.join(D, "index.json")))
dists = list(range(150, 390, 10))
LAT = 8.0 * 0.45 ** 0.75
A_DRY = 70.0 / 3.6 * 0.45 ** 0.87
VTOP = 270.0 * 0.88 / 3.6
cases = []
n_all = 0
first_fail = {}
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
    X = np.concatenate([[0.0], np.cumsum(theta * seg + kappa * seg * seg * 0.5)])[:n]
    # fastest drivable speed at every segment: curve limit (5 % tolerance) with the braking envelope backwards
    vs = np.minimum(VTOP, 1.05 * np.sqrt(LAT * R1 / np.maximum(np.abs(curve), 1e-4)))
    v = vs.copy()
    for i in range(n - 2, -1, -1):
        v[i] = min(v[i], np.sqrt(v[i + 1] ** 2 + 2.0 * A_DRY * seg))
    need = v * 1.0 + v * v / (2.0 * A_DRY)          # 1 s reaction + full braking to a standstill, dry
    nz = int(e["length_z"] / seg)
    cam = np.arange(4, nz - int(760 / seg) - 2, 2)
    if len(cam) == 0:
        continue
    kl = int(LOOK / seg)
    th = theta[cam]
    dxw = px[cam + kl] - px[cam]; dzw = pz[cam + kl] - pz[cam]
    phi = GAIN * np.arctan2(dxw * np.cos(th) - dzw * np.sin(th), dxw * np.sin(th) + dzw * np.cos(th))
    yaw = th + phi
    car = cam + 3
    for d in dists:
        k = int(d / seg)
        for xt in (-3.75, 0.0, 3.75):
            n_all += len(cam)
            sx_a = (X[cam + k] - X[cam] - theta[cam] * (k * seg) + xt) * F / (k * seg)
            on_a = np.abs(sx_a) <= HALF
            tht = theta[cam + k]
            tx = px[cam + k] + xt * np.cos(tht) - px[cam]; tz = pz[cam + k] - xt * np.sin(tht) - pz[cam]
            vx = tx * np.cos(yaw) - tz * np.sin(yaw); vz = tx * np.sin(yaw) + tz * np.cos(yaw)
            on_3 = (vz > 0.5) & (np.abs(vx / np.maximum(vz, 0.5) * F) <= HALF)
            bad = on_a & ~on_3
            if bad.any():
                nd = need[car[bad]]
                first_fail.setdefault(d, [0, 0.0, 0.0])
                first_fail[d][0] += int(bad.sum())
                first_fail[d][1] = max(first_fail[d][1], float(nd.max()))
                first_fail[d][2] = max(first_fail[d][2], float((v[car[bad]] * 3.6).max()))
                j = int(np.argmax(nd))
                worst.append((float(nd[j]) / d, d, e["name"], float(cam[bad][j] * seg * e["length_km"] / e["length_z"]), float(nd[j]), float(v[car[bad]][j] * 3.6), float(np.abs(curve[car[bad]][j]))))
print("policy: yaw = %.2f x bearing of the centreline %d m ahead; samples %d" % (GAIN, LOOK, n_all))
print("d (m): cases [Arcade on screen, 3D off] / max stopping sight distance there (m) / max drivable speed (km/h)")
for d in sorted(first_fail):
    c = first_fail[d]
    print("  %3d: %6d   need <= %5.1f m   v <= %5.1f km/h   %s" % (d, c[0], c[1], c[2], "OK" if c[1] < d else "!!"))
if not first_fail:
    print("  none")
worst.sort(reverse=True)
for w in worst[:5]:
    print("  worst need/d %.2f: d=%d %s km %.1f need %.0f m v %.0f km/h |curve| %.2f" % w)
