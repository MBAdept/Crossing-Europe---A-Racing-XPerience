#!/usr/bin/env python3
"""KRITIK-R3: tail of the per-crash limiter gain reduction (heavy truck crashes, truck.heavy -11.5) pooled over runs,
and the binomial risk that a 60-crash acceptance has a p95 (np.percentile) above 3 dB: p95 > 3 needs about the 4
largest of 60 above 3 dB (index 56.05 of 0..59). usage: tail.py <res.json> ..."""
import json, math, sys
import numpy as np
gr = []
per = []
for p in sys.argv[1:]:
    r = json.load(open(p))
    g = [row["gr_max"] for row in r["rows"]]
    gr += g
    per.append((p.rsplit("/", 1)[-1], round(float(np.percentile(g, 95)), 2)))
gr = np.array(gr)
n = len(gr)
print("runs", per)
for t in (2.0, 2.5, 2.8, 3.0):
    print(f"share > {t} dB: {(gr > t).sum()} of {n} = {(gr > t).mean():.3f}")
p3 = (gr > 3.0).mean()
for p in (p3, 2 * p3, 3 * p3):
    lam = 60 * p
    risk = 1 - sum(math.comb(60, k) * p ** k * (1 - p) ** (60 - k) for k in range(4))
    print(f"per-crash P(>3 dB) {p:.3f}: risk p95 > 3 in a 60-crash run (>= 4 of 60 above 3 dB) {risk:.4f}")
# empirical: p95 of 60-crash runs drawn without replacement from the pool (subsampling instead of bootstrap)
rng = np.random.default_rng(4711)
sub = np.array([np.percentile(rng.choice(gr, 60, replace=False), 95) for _ in range(20000)])
print(f"subsampled 60-runs: p95 median {np.median(sub):.2f}, 95 % range {np.percentile(sub, 2.5):.2f}-{np.percentile(sub, 97.5):.2f}, share > 3 dB {(sub > 3).mean():.4f}, share > 2.8 dB {(sub > 2.8).mean():.3f}")
