#!/usr/bin/env python3
import json, sys, os
import numpy as np
D = sys.argv[1]
R1 = 120.0
idx = json.load(open(os.path.join(D, "index.json")))
out = []
curv_km = {0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0}
hills_km = {0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0}
for e in idx:
    if e["dev"]:
        continue
    for s in e["sections"]:
        curv_km[int(s["curviness"])] += s["end_km"] - s["start_km"]
        hills_km[int(s["hills"])] += s["end_km"] - s["start_km"]
    a = np.fromfile(os.path.join(D, e["name"] + ".f32"), dtype=np.float32).reshape(-1, 4)
    seg = e["seg_len"]
    curve = a[:, 0].astype(np.float64)
    y = a[:, 1].astype(np.float64)
    n = len(curve)
    kappa = curve / R1
    theta = np.concatenate([[0.0], np.cumsum(kappa * seg)])[:n]
    px = np.concatenate([[0.0], np.cumsum(np.sin(theta + kappa * seg * 0.5) * seg)])[:n]
    pz = np.concatenate([[0.0], np.cumsum(np.cos(theta + kappa * seg * 0.5) * seg)])[:n]
    st = 4
    P = np.stack([px[::st], pz[::st]], axis=1)
    Y = y[::st]
    TH = theta[::st]
    m = len(P)
    r = {"name": e["name"], "km": e["length_km"], "len_m": n * seg}
    for dist in (960.0, 1900.0):
        kmin = int(360.0 / (seg * st))
        kmax = int(dist / (seg * st))
        mind = np.full(m, np.inf)
        marc = np.zeros(m); mdy = np.zeros(m); mdth = np.zeros(m)
        for k in range(kmin, min(kmax, m - 1) + 1):
            d = np.hypot(P[k:, 0] - P[:-k, 0], P[k:, 1] - P[:-k, 1])
            upd = d < mind[:m - k]
            mind[:m - k] = np.where(upd, d, mind[:m - k])
            marc[:m - k] = np.where(upd, k * seg * st, marc[:m - k])
            mdy[:m - k] = np.where(upd, Y[k:] - Y[:-k], mdy[:m - k])
            mdth[:m - k] = np.where(upd, TH[k:] - TH[:-k], mdth[:m - k])
        tag = "%d" % int(dist)
        for W in (100, 150, 200, 250, 300):
            r["p%s_lt%d" % (tag, W)] = float((mind < W).sum() * seg * st)
        i0 = int(np.argmin(mind))
        r["p%s_min" % tag] = float(mind[i0]); r["p%s_arc" % tag] = float(marc[i0]); r["p%s_dy" % tag] = float(mdy[i0])
        r["p%s_dth" % tag] = float(np.degrees(mdth[i0])); r["p%s_km" % tag] = float(i0 * st * seg * e["length_km"] / e["length_z"])
    r["abs_curve_p99"] = float(np.percentile(np.abs(curve), 99)); r["max_curve"] = float(np.abs(curve).max())
    # sharpest radius
    r["min_radius_m"] = float(R1 / max(1e-6, np.abs(curve).max()))
    # lateral extent of the true path and of the sheared (arcade) path
    X = np.concatenate([[0.0], np.cumsum(np.concatenate([[0.0], np.cumsum(kappa * seg)])[:n] * seg)])[:n]
    r["arcade_X_range_km"] = float((X.max() - X.min()) / 1000.0)
    r["true_extent_km"] = float(max(px.max() - px.min(), pz.max() - pz.min()) / 1000.0)
    r["max_abs_coord_km"] = float(max(np.abs(px).max(), np.abs(pz).max()) / 1000.0)
    r["max_slope_arcade"] = float(np.abs(theta).max())
    out.append(r)
json.dump(out, open(os.path.join(D, "scan2.json"), "w"), indent=1)
L = sum(r["len_m"] for r in out)
print("sections by curviness (odometer km):", {k: round(v) for k, v in curv_km.items()}, " hills:", {k: round(v) for k, v in hills_km.items()})
for tag in ("960", "1900"):
    for W in (100, 150, 200, 250, 300):
        k = "p%s_lt%d" % (tag, W)
        print("true 3D: another part of the road (360..%s m of path away) closer than %3d m: %7.0f m of road = %.3f %%, %3d stage directions" % (tag, W, sum(r[k] for r in out), 100 * sum(r[k] for r in out) / L, sum(1 for r in out if r[k] > 0)))
print("closest approach (within 960 m of path), worst 10:")
for r in sorted(out, key=lambda r: r["p960_min"])[:10]:
    print("  %-34s min %6.1f m  arc %4.0f m  dy %+6.1f m  dtheta %+5.0f deg  km %6.1f  min radius %4.0f m" % (r["name"], r["p960_min"], r["p960_arc"], r["p960_dy"], r["p960_dth"], r["p960_km"], r["min_radius_m"]))
print("closest approach (within 1900 m of path), worst 10:")
for r in sorted(out, key=lambda r: r["p1900_min"])[:10]:
    print("  %-34s min %6.1f m  arc %4.0f m  dy %+6.1f m  dtheta %+5.0f deg  km %6.1f" % (r["name"], r["p1900_min"], r["p1900_arc"], r["p1900_dy"], r["p1900_dth"], r["p1900_km"]))
print("max |coordinate| of the true path: %.1f km; arcade X range max %.0f km; max arcade slope |theta| %.1f rad" % (max(r["max_abs_coord_km"] for r in out), max(r["arcade_X_range_km"] for r in out), max(r["max_slope_arcade"] for r in out)))
print("min radius over all: %.0f m; stages with max|curve|>0.6: %d" % (min(r["min_radius_m"] for r in out), sum(1 for r in out if r["max_curve"] > 0.6)))
