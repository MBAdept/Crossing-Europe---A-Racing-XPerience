#!/usr/bin/env python3
"""Scan of all stage directions: integrated true-3D centreline (heading from curve), self-proximity inside the
draw distance, heading windows. Input: dump_tracks.gd output. (design study v0.8.0)"""
import json, sys, os
import numpy as np

D = sys.argv[1]
R1 = 120.0
idx = json.load(open(os.path.join(D, "index.json")))
rows = []
tot_len = 0.0
agg = {}
for e in idx:
    a = np.fromfile(os.path.join(D, e["name"] + ".f32"), dtype=np.float32).reshape(-1, 4)
    seg = e["seg_len"]
    curve = a[:, 0].astype(np.float64)
    y = a[:, 1].astype(np.float64)
    n = len(curve)
    kappa = curve / R1
    theta = np.concatenate([[0.0], np.cumsum(kappa * seg)])[:n]       # heading at segment start (rad)
    px = np.concatenate([[0.0], np.cumsum(np.sin(theta + kappa * seg * 0.5) * seg)])[:n]
    pz = np.concatenate([[0.0], np.cumsum(np.cos(theta + kappa * seg * 0.5) * seg)])[:n]
    res = {"name": e["name"], "dev": e["dev"], "km": e["length_km"], "n": n,
           "theta_min_deg": float(np.degrees(theta.min())), "theta_max_deg": float(np.degrees(theta.max())),
           "theta_end_deg": float(np.degrees(theta[-1])), "max_curve": float(np.abs(curve).max())}
    # heading change inside windows
    for win in (300.0, 495.0, 900.0, 960.0):
        w = int(win / seg)
        # max |theta[i+k]-theta[i]| for k<=w : use running max/min via stride tricks (coarse: step 4 segments)
        st = 4
        th = theta[::st]
        ww = max(1, w // st)
        best = 0.0
        # sliding window max-min
        from numpy.lib.stride_tricks import sliding_window_view
        if len(th) > ww + 1:
            v = sliding_window_view(th, ww + 1)
            best = float(np.max(np.abs(v - v[:, :1])))
        res["dtheta_%d_deg" % int(win)] = float(np.degrees(best))
    # self proximity: pairs (i, j) with gap_min <= (j-i)*seg <= dist, euclid distance < W
    st = 4                                    # 12 m resolution
    P = np.stack([px[::st], pz[::st]], axis=1)
    Y = y[::st]
    m = len(P)
    for dist, tag in ((960.0, "960"), (1900.0, "1900")):
        kmin = int(150.0 / (seg * st))        # ignore the immediate neighbourhood (150 m of path)
        kmax = int(dist / (seg * st))
        mind = np.full(m, np.inf)
        mdy = np.zeros(m)
        marc = np.zeros(m)
        for k in range(kmin, kmax + 1):
            if k >= m:
                break
            d = np.hypot(P[k:, 0] - P[:-k, 0], P[k:, 1] - P[:-k, 1])
            # only pairs whose separation is much shorter than the path between them (a loop, not a straight)
            upd = d < mind[:m - k]
            mind[:m - k] = np.where(upd, d, mind[:m - k])
            mdy[:m - k] = np.where(upd, Y[k:] - Y[:-k], mdy[:m - k])
            marc[:m - k] = np.where(upd, k * seg * st, marc[:m - k])
        for W in (40.0, 80.0, 150.0):
            hit = mind < W
            res["prox%s_lt%d_m" % (tag, int(W))] = float(hit.sum() * seg * st)   # metres of road affected (camera positions)
        res["prox%s_min_m" % tag] = float(mind.min()) if m > kmin else None
        i0 = int(np.argmin(mind)) if m > kmin else 0
        res["prox%s_min_at_km" % tag] = float(i0 * st * seg * e["length_km"] / max(e["length_z"], 1.0))
        res["prox%s_min_arc_m" % tag] = float(marc[i0])
        res["prox%s_min_dy_m" % tag] = float(mdy[i0])
    # relative heading at which the road ahead points back towards the camera within the draw distance
    w = int(900.0 / seg)
    th = theta
    over90 = 0
    over150 = 0
    stp = 8
    for i in range(0, n - w, stp):
        dth = np.abs(th[i:i + w] - th[i])
        mx = dth.max()
        if mx > np.pi / 2: over90 += 1
        if mx > np.radians(150): over150 += 1
    res["cam_m_with_ahead_gt90deg"] = over90 * stp * seg
    res["cam_m_with_ahead_gt150deg"] = over150 * stp * seg
    res["len_m"] = n * seg
    rows.append(res)

json.dump(rows, open(os.path.join(D, "scan.json"), "w"), indent=1)
real = [r for r in rows if not r["dev"]]
print("stage directions:", len(rows), "(non-dev %d)" % len(real))
L = sum(r["len_m"] for r in real)
print("total road %.0f km visible metres (%.0f odometer km)" % (L / 1000.0, sum(r["km"] for r in real)))
def tot(key):
    return sum(r[key] for r in real)
for tag in ("960", "1900"):
    for W in (40, 80, 150):
        k = "prox%s_lt%d_m" % (tag, W)
        nst = sum(1 for r in real if r[k] > 0)
        print("self-proximity < %3d m within %s m of path: %8.0f m of road (%.2f %%), %d of %d stage directions" % (W, tag, tot(k), 100.0 * tot(k) / L, nst, len(real)))
print("cumulative heading: max |theta| = %.0f deg (%s)" % max((max(abs(r["theta_min_deg"]), abs(r["theta_max_deg"])), r["name"]) for r in real))
print("heading range (max-min) median %.0f deg, max %.0f deg" % (np.median([r["theta_max_deg"] - r["theta_min_deg"] for r in real]), max(r["theta_max_deg"] - r["theta_min_deg"] for r in real)))
for win in (300, 495, 900, 960):
    k = "dtheta_%d_deg" % win
    vals = [r[k] for r in real]
    print("max heading change inside %d m: median %.0f deg, p90 %.0f, max %.0f deg (%s)" % (win, np.median(vals), np.percentile(vals, 90), max(vals), max(real, key=lambda r: r[k])["name"]))
print("camera positions with road ahead (<=900 m) turned > 90 deg: %.0f m (%.2f %%), > 150 deg: %.0f m (%.2f %%)" % (tot("cam_m_with_ahead_gt90deg"), 100 * tot("cam_m_with_ahead_gt90deg") / L, tot("cam_m_with_ahead_gt150deg"), 100 * tot("cam_m_with_ahead_gt150deg") / L))
print()
print("worst 12 by self-proximity (<80 m within 960 m):")
for r in sorted(real, key=lambda r: -r["prox960_lt80_m"])[:12]:
    print("  %-34s %5.0f km  max|curve| %.2f  <40: %5.0f m  <80: %5.0f m  <150: %5.0f m  min %5.1f m (arc %4.0f m, dy %+5.1f m, km %.1f)  dtheta900 %3.0f deg" % (
        r["name"], r["km"], r["max_curve"], r["prox960_lt40_m"], r["prox960_lt80_m"], r["prox960_lt150_m"], r["prox960_min_m"], r["prox960_min_arc_m"], r["prox960_min_dy_m"], r["prox960_min_at_km"], r["dtheta_900_deg"]))
