#!/usr/bin/env python3
"""Fairness part 2 (crests): from how far is a target (vehicle 0.75 m, sign board 2.8 m above the road) seen over the
crests? Arcade model (tests/sim/sight_check.gd: sight line over the road profile, depth = road distance) against
true 3D: straight sight line through the 3D world over a terrain that continues every cross-section at road height
(ruled surface) - the same camera (9 m behind the car, 3.4 m above the road at the car). Optional terrain relief:
RELIEF=<m> raises the ground beyond 10 m from the centreline by that much (what a careless terrain would do).
(design study v0.8.0)"""
import json, sys, os
import numpy as np
D = sys.argv[1]
R1 = 120.0
CAM_H, CAM_D = 3.4, 9.0
VIS = 900.0
DMAX = 0.839 * VIS
RELIEF = float(os.environ.get("RELIEF", "0"))
RELIEF_FROM = float(os.environ.get("RELIEF_FROM", "10"))
RIBBON = float(os.environ.get("RIBBON", "1e9"))   # half width of the terrain ribbon (m); beyond it only the base plane far below
ONLY = os.environ.get("ONLY", "")
STEP_T = float(os.environ.get("STEP_T", "300"))
idx = json.load(open(os.path.join(D, "index.json")))
rng = np.random.default_rng(7)
rows = []
for e in idx:
    if e["dev"] or (ONLY and not any(o in e["name"] for o in ONLY.split(","))):
        continue
    a = np.fromfile(os.path.join(D, e["name"] + ".f32"), dtype=np.float32).reshape(-1, 4)
    seg = e["seg_len"]
    curve = a[:, 0].astype(np.float64); y = a[:, 1].astype(np.float64)
    n = len(curve)
    kappa = curve / R1
    theta = np.concatenate([[0.0], np.cumsum(kappa * seg)])[:n]
    px = np.concatenate([[0.0], np.cumsum(np.sin(theta + kappa * seg * 0.5) * seg)])[:n]
    pz = np.concatenate([[0.0], np.cumsum(np.cos(theta + kappa * seg * 0.5) * seg)])[:n]
    vs = np.minimum(270.0 / 3.6, 1.05 * np.sqrt(8.0 * R1 / np.maximum(np.abs(curve), 1e-4)))
    vv = vs.copy()
    A = 70.0 / 3.6
    for i in range(n - 2, -1, -1):
        vv[i] = min(vv[i], np.sqrt(vv[i + 1] ** 2 + 2.0 * A * seg))
    need_all = vv + vv * vv / (2.0 * A)
    nz = int(e["length_z"] / seg)
    kmax = int(DMAX / seg)
    targets = np.arange(kmax + 8, nz - 4, int(STEP_T / seg))
    for kt in targets:
        k0 = kt - kmax - 4
        yy = y[k0:kt + 1]
        if yy.max() - yy.min() < 1.5:
            continue                                  # flat: nothing can hide anything
        curved = np.abs(curve[k0:kt + 1]).max() > 0.08
        for th_t, tag in ((0.75, "car"), (2.8, "sign")):
            yt = y[kt] + th_t
            best_a = 0.0; best_3 = 0.0
            # camera segment index kc (camera position), car 3 segments ahead of it
            for kc in range(kt - 2, k0 + 3, -2):
                d = (kt - kc) * seg
                yc = y[min(kc + 3, n - 1)] + CAM_H
                ks = np.arange(kc + 1, kt)
                if len(ks) == 0:
                    best_a = d; best_3 = d
                    continue
                # arcade: profile test, linear in road distance
                t = (ks - kc) / float(kt - kc)
                los_a = bool(np.all(y[ks] <= yc + (yt - yc) * t + 0.05))
                if los_a:
                    best_a = d
                if not curved:
                    if los_a:
                        best_3 = d
                    continue
                # true 3D: ray from the camera to the target, sampled every ~6 m; ground height under each sample
                m = max(2, int(d / 6.0))
                tt = (np.arange(1, m) / float(m))
                qx = px[kc] + (px[kt] - px[kc]) * tt; qz = pz[kc] + (pz[kt] - pz[kc]) * tt
                w = np.arange(kc, kt + 1, 2)
                dd = (qx[:, None] - px[w][None, :]) ** 2 + (qz[:, None] - pz[w][None, :]) ** 2
                j = np.argmin(dd, axis=1)
                lat = np.sqrt(dd[np.arange(len(j)), j])
                ground = np.where(lat > np.minimum(RIBBON, 0.8 * R1 / np.maximum(np.abs(curve[w][j]), 1e-4)), -1.0e6, y[w][j] + np.where(lat > RELIEF_FROM, RELIEF, 0.0))
                los_3 = bool(np.all(ground <= yc + (yt - yc) * tt + 0.05))
                if los_3:
                    best_3 = d
            kc3 = int(kt - best_3 / seg)
            need3 = float(need_all[min(max(kc3 + 3, 0), n - 1)])
            kca = int(kt - best_a / seg)
            needa = float(need_all[min(max(kca + 3, 0), n - 1)])
            rows.append((e["name"], kt * seg, tag, curved, best_a, best_3, need3, needa))
import collections
print("targets: %d (every %d m where the road ahead of the camera is not flat), relief %.1f m beyond %.0f m, ribbon half width %.0f m" % (len(rows) // 2, STEP_T, RELIEF, RELIEF_FROM, RIBBON))
for tag in ("car", "sign"):
    r = [x for x in rows if x[2] == tag]
    da = np.array([x[4] for x in r]); d3 = np.array([x[5] for x in r]); cv = np.array([x[3] for x in r])
    delta = d3 - da
    lim = da < DMAX - 7.0          # crest-limited in arcade
    print("%s: seen from (m) arcade p10 %.0f p50 %.0f | 3D p10 %.0f p50 %.0f | crest-limited targets %d (%.1f %%)" % (tag, np.percentile(da, 10), np.percentile(da, 50), np.percentile(d3, 10), np.percentile(d3, 50), lim.sum(), 100.0 * lim.mean()))
    print("   3D - arcade (m): min %.0f  p1 %.0f  p5 %.0f  p50 %.0f  p95 %.0f  max %.0f ; 3D later by > 6 m: %d (%.2f %%), > 30 m: %d ; 3D earlier by > 6 m: %d (%.2f %%)" % (
        delta.min(), np.percentile(delta, 1), np.percentile(delta, 5), np.percentile(delta, 50), np.percentile(delta, 95), delta.max(), (delta < -6.5).sum(), 100.0 * (delta < -6.5).mean(), (delta < -30).sum(), (delta > 6.5).sum(), 100.0 * (delta > 6.5).mean()))
    later = [x for x in r if x[5] - x[4] < -6.5]
    short3 = [x for x in later if x[5] < x[6]]
    shorta = [x for x in r if x[4] < x[7]]
    short3_all = [x for x in r if x[5] < x[6]]
    print("   arcade: seen from less than the stopping sight distance (dry, fastest drivable speed, 1 s reaction): %d of %d (%.2f %%); 3D: %d (%.2f %%)" % (len(shorta), len(r), 100.0 * len(shorta) / len(r), len(short3_all), 100.0 * len(short3_all) / len(r)))
    print("   3D later than arcade AND then inside the stopping sight distance: %d ; of them already short in arcade: %d" % (len(short3), len([x for x in short3 if x[4] < x[7]])))
    for b in sorted(short3, key=lambda x: x[5] - x[6])[:6]:
        print("     short: %s z %.0f: arcade %.0f m (need %.0f), 3D %.0f m (need %.0f)" % (b[0], b[1], b[4], b[7], b[5], b[6]))
    bad = sorted(later, key=lambda x: x[5] - x[4])[:6]
    for b in bad:
        print("     %s z %.0f: arcade %.0f m, 3D %.0f m" % (b[0], b[1], b[4], b[5]))
