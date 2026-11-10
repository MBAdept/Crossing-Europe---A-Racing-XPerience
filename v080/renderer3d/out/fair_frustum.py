#!/usr/bin/env python3
"""Fairness, part 1 (curves): is a vehicle d metres ahead on screen horizontally? Arcade (parabola / shear projection)
against true 3D (arcs) with a tangent camera and with look-into-the-curve yaw policies. All stage directions,
camera every 12 m. (design study v0.8.0)"""
import json, sys, os
import numpy as np
D = sys.argv[1]
R1 = 120.0
F = 640.0 / np.tan(np.radians(42.0))      # 711 px
HALF = 640.0
idx = json.load(open(os.path.join(D, "index.json")))
dists = [50, 100, 150, 200, 250, 300, 400, 500, 600, 755]
policies = {"tangent": (0.0, 60.0), "look 0.5@60": (0.5, 60.0), "look 0.75@60": (0.75, 60.0), "look 1.0@60": (1.0, 60.0), "look 0.75@80": (0.75, 80.0), "look 0.6@100": (0.6, 100.0)}
tot = 0
arc_on = {d: 0 for d in dists}
res = {p: {d: [0, 0, 0] for d in dists} for p in policies}     # [3d on, arcade on & 3d off, arcade off & 3d on]
car_px = {p: [] for p in policies}
yaw_max = {p: 0.0 for p in policies}
scale_gain = {d: [] for d in dists}
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
    X = np.concatenate([[0.0], np.cumsum(theta * seg + kappa * seg * seg * 0.5)])[:n]    # arcade: X'' = kappa
    nz = int(e["length_z"] / seg)
    cam = np.arange(4, nz - int(760 / seg) - 2, 4)                 # camera segment index, every 12 m
    if len(cam) == 0:
        continue
    tot += len(cam) * 3
    for pol, (gain, look) in policies.items():
        kl = int(look / seg)
        # bearing of the centreline point `look` m ahead of the camera, relative to the camera tangent
        dxw = px[cam + kl] - px[cam]; dzw = pz[cam + kl] - pz[cam]
        th = theta[cam]
        lx = dxw * np.cos(th) - dzw * np.sin(th); lz = dxw * np.sin(th) + dzw * np.cos(th)
        phi = gain * np.arctan2(lx, lz)
        yaw_max[pol] = max(yaw_max[pol], float(np.degrees(np.abs(phi).max())))
        # player car (9 m ahead of the camera on the path): screen offset from the centre
        k9 = 3
        dxw = px[cam + k9] - px[cam]; dzw = pz[cam + k9] - pz[cam]
        yaw = th + phi
        cx = dxw * np.cos(yaw) - dzw * np.sin(yaw); cz = dxw * np.sin(yaw) + dzw * np.cos(yaw)
        car_px[pol].append(np.abs(cx / cz * F))
        for d in dists:
            k = int(d / seg)
            for xt in (-3.75, 0.0, 3.75):
                # arcade
                sx_a = (X[cam + k] - X[cam] - theta[cam] * (k * seg) + xt) * F / (k * seg)
                on_a = np.abs(sx_a) <= HALF
                # true 3D
                tht = theta[cam + k]
                tx = px[cam + k] + xt * np.cos(tht) - px[cam]; tz = pz[cam + k] - xt * np.sin(tht) - pz[cam]
                vx = tx * np.cos(yaw) - tz * np.sin(yaw); vz = tx * np.sin(yaw) + tz * np.cos(yaw)
                on_3 = (vz > 0.5) & (np.abs(vx / np.maximum(vz, 0.5) * F) <= HALF)
                if pol == "tangent":
                    arc_on[d] += int(on_a.sum())
                    if xt == 0.0:
                        scale_gain[d].append(((k * seg) / np.maximum(vz, 0.5))[on_a & on_3])
                r = res[pol][d]
                r[0] += int(on_3.sum()); r[1] += int((on_a & ~on_3).sum()); r[2] += int((~on_a & on_3).sum())
print("camera positions x 3 lanes: %d (every 12 m, %d stage directions)" % (tot, sum(1 for e in idx if not e['dev'])))
print("%-14s " % "distance m" + " ".join("%8d" % d for d in dists))
print("%-14s " % "arcade on %" + " ".join("%8.3f" % (100.0 * arc_on[d] / tot) for d in dists))
for pol in policies:
    print("%-14s " % (pol + " on%") + " ".join("%8.3f" % (100.0 * res[pol][d][0] / tot) for d in dists))
    print("%-14s " % "  A on, 3D off" + " ".join("%8d" % res[pol][d][1] for d in dists))
    print("%-14s " % "  A off, 3D on" + " ".join("%8d" % res[pol][d][2] for d in dists))
    c = np.concatenate(car_px[pol])
    print("    max camera yaw %.1f deg; player car off-centre: p50 %.1f px, p99 %.1f px, max %.1f px" % (yaw_max[pol], np.percentile(c, 50), np.percentile(c, 99), c.max()))
print("apparent size in 3D relative to arcade (road distance / view depth), target on screen in both:")
for d in dists:
    g = np.concatenate(scale_gain[d])
    print("  d=%3d: p50 %.3f  p99 %.3f  max %.3f  min %.3f" % (d, np.percentile(g, 50), np.percentile(g, 99), g.max(), g.min()))
