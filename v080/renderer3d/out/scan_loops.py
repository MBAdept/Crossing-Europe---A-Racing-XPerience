#!/usr/bin/env python3
"""Loops of the integrated true-3D centreline: closest approach of two road parts 1100..8000 m of path apart (they are
never loaded at the same time when chunks are streamed by path distance). (design study v0.8.0)"""
import json, numpy as np, os, sys
D = sys.argv[1]
idx = json.load(open(D + '/index.json'))
res = []
for e in idx:
    if e['dev']:
        continue
    a = np.fromfile(D + '/' + e['name'] + '.f32', dtype=np.float32).reshape(-1, 4)
    seg = e['seg_len']; curve = a[:, 0].astype(float); n = len(curve); kappa = curve / 120.0
    theta = np.concatenate([[0.0], np.cumsum(kappa * seg)])[:n]
    px = np.concatenate([[0.0], np.cumsum(np.sin(theta + kappa * seg * 0.5) * seg)])[:n]
    pz = np.concatenate([[0.0], np.cumsum(np.cos(theta + kappa * seg * 0.5) * seg)])[:n]
    st = 8; P = np.stack([px[::st], pz[::st]], axis=1); m = len(P)
    best = (1e9, 0, 0)
    for k in range(int(1100 / (seg * st)), min(m - 1, int(8000 / (seg * st))) + 1):
        d = np.hypot(P[k:, 0] - P[:-k, 0], P[k:, 1] - P[:-k, 1])
        j = int(np.argmin(d))
        if d[j] < best[0]:
            best = (float(d[j]), k * seg * st, j * st * seg * e['length_km'] / e['length_z'])
    res.append((best[0], e['name'], best[1], best[2]))
res.sort()
print('closest approach of two road parts 1100..8000 m of path apart:')
for r in res[:12]:
    print('  %6.1f m  %-34s path apart %5.0f m at km %.1f' % r)
print('stage directions with such an approach < 100 m: %d, < 30 m (the true-3D road would cross itself): %d of %d' % (sum(1 for r in res if r[0] < 100), sum(1 for r in res if r[0] < 30), len(res)))
print('smallest path separation of an approach < 150 m: %.0f m' % min([r[2] for r in res if r[0] < 150] or [0]))
